#!/usr/bin/env python3
"""Global menu bridge for the cozytile bar.

Acts as the session's com.canonical.AppMenu.Registrar (what Qt, GTK-module, Firefox, ... talk to
when an app has a menu bar to export), then reads the menu of the focused app over
com.canonical.dbusmenu and forwards it to the shell.

stdin  (one command per line)
    watch <pid>              follow the menu of the window owned by <pid> (0 = none)
    show <pid> <id>          AboutToShow for an item, then refresh (call before opening a submenu)
    click <pid> <id>         activate an item
Sources: dbusmenu (registered through the registrar) and GTK's org.gtk.Menus (GApplication
menubar, discovered by scanning the session bus for the app's exported menu paths).
stdout (one JSON object per line)
    {"type":"status","registrar":true|false}
    {"type":"menu","pid":N,"items":[{id,label,enabled,sep,toggle,state,shortcut,children}]}
"""
import json
import os
import sys

import gi
gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

REG_NAME = "com.canonical.AppMenu.Registrar"
REG_PATH = "/com/canonical/AppMenu/Registrar"
REG_XML = """
<node>
  <interface name="com.canonical.AppMenu.Registrar">
    <method name="RegisterWindow"><arg type="u" direction="in"/><arg type="o" direction="in"/></method>
    <method name="UnregisterWindow"><arg type="u" direction="in"/></method>
    <method name="GetMenuForWindow"><arg type="u" direction="in"/><arg type="s" direction="out"/><arg type="o" direction="out"/></method>
    <signal name="WindowRegistered"><arg type="u"/><arg type="s"/><arg type="o"/></signal>
    <signal name="WindowUnregistered"><arg type="u"/></signal>
  </interface>
</node>
"""
DBUSMENU = "com.canonical.dbusmenu"

bus = None
regs = {}            # window id -> {service, path, pid, seq}
seq = 0
current = 0          # pid the shell is watching
pending = None       # GLib timeout source for debounced refresh
subs = {}            # service -> [subscription ids]
gtk_regs = {}        # unique bus name -> GTK registration (kind "gtk") or None
GTK_MENUS = "org.gtk.Menus"
GTK_ACTIONS = "org.gtk.Actions"


def out(obj):
    sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def pid_of(name):
    try:
        r = bus.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
                          "GetConnectionUnixProcessID", GLib.Variant("(s)", (name,)),
                          GLib.VariantType("(u)"), Gio.DBusCallFlags.NONE, 1000, None)
        return r.unpack()[0]
    except GLib.Error:
        return 0


def ppid(pid):
    try:
        with open(f"/proc/{pid}/stat") as f:
            return int(f.read().rsplit(")", 1)[1].split()[1])
    except (OSError, ValueError, IndexError):
        return 0


def ancestors(pid):
    seen = []
    while pid > 1 and len(seen) < 12:
        seen.append(pid)
        pid = ppid(pid)
    return seen


# ---- GTK (org.gtk.Menus / org.gtk.Actions) ----------------------------------------------------

def sync(service, path, iface, method, params, sig):
    try:
        r = bus.call_sync(service, path, iface, method, params, GLib.VariantType(sig),
                          Gio.DBusCallFlags.NONE, 1500, None)
        return r.unpack()
    except GLib.Error:
        return None


def sweep(service, path="/", depth=0, found=None):
    """Object paths under `service` and the GTK interfaces each exports."""
    found = {} if found is None else found
    try:
        r = bus.call_sync(service, path, "org.freedesktop.DBus.Introspectable", "Introspect", None,
                          GLib.VariantType("(s)"), Gio.DBusCallFlags.NONE, 800, None)
        info = Gio.DBusNodeInfo.new_for_xml(r.unpack()[0])
    except GLib.Error:
        return found
    names = {i.name for i in info.interfaces}
    if GTK_MENUS in names or GTK_ACTIONS in names:
        found[path] = names
    if depth < 5:
        for n in info.nodes:
            sweep(service, (path.rstrip("/") + "/" + n.path), depth + 1, found)
    return found


def gtk_find(pid):
    """GTK registration owned by `pid` or a descendant, scanning the bus when not yet known."""
    if pid <= 0:
        return None
    try:
        names = bus.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
                              "ListNames", None, GLib.VariantType("(as)"), Gio.DBusCallFlags.NONE, 1000, None).unpack()[0]
    except GLib.Error:
        return None
    for name in names:
        if not name.startswith(":"):
            continue
        npid = pid_of(name)
        if not npid or not (npid == pid or pid in ancestors(npid)):
            continue
        reg = gtk_regs.get(name)
        if reg is None:
            found = sweep(name)
            bars = [p for p, i in found.items() if GTK_MENUS in i and p.endswith("/menus/menubar")]
            if not bars:
                continue
            app = bars[0][:-len("/menus/menubar")] or "/"
            wins = [p for p, i in found.items() if GTK_ACTIONS in i and "/window/" in p]
            reg = {"service": name, "path": bars[0], "pid": npid, "seq": 0, "kind": "gtk",
                   "app": app, "win": sorted(wins)[0] if wins else None, "ids": {}}
            gtk_regs[name] = reg
            subs.setdefault(name, [])
            subs[name].append(bus.signal_subscribe(name, GTK_MENUS, "Changed", None, None,
                                                   Gio.DBusSignalFlags.NONE, on_menu_signal, None))
        return reg
    return None


ACCEL_MODS = {"Control": "Ctrl", "Primary": "Ctrl", "Shift": "Shift", "Alt": "Alt", "Super": "Meta", "Meta": "Meta"}


def gtk_accel(acc):
    if not acc:
        return ""
    mods, key = [], acc
    while key.startswith("<") and ">" in key:
        m, key = key[1:].split(">", 1)
        mods.append(ACCEL_MODS.get(m, m))
    key = {"Delete": "Del", "Escape": "Esc"}.get(key, key.upper() if len(key) == 1 else key)
    return "+".join(mods + [key])


def gtk_actions(reg):
    """'app.x' / 'win.x' -> (object path, name, enabled, state) from DescribeAll."""
    table = {}
    for prefix, path in (("app", reg["app"]), ("win", reg["win"])):
        if not path:
            continue
        r = sync(reg["service"], path, GTK_ACTIONS, "DescribeAll", None, "(a{s(bgav)})")
        if r:
            for name, (en, _sig, st) in r[0].items():
                table[f"{prefix}.{name}"] = (path, name, en, st[0] if st else None)
    return table


def gtk_menus(reg):
    """Every menu of the exported menubar, following :section / :submenu links across groups."""
    menus, want, done = {}, [0], set()
    while want:
        g = want.pop()
        if g in done:
            continue
        done.add(g)
        r = sync(reg["service"], reg["path"], GTK_MENUS, "Start", GLib.Variant("(au)", ([g],)), "(a(uuaa{sv}))")
        for grp, mid, items in (r[0] if r else []):
            menus[(grp, mid)] = items
            for it in items:
                for k in (":section", ":submenu"):
                    if k in it and it[k][0] not in done:
                        want.append(it[k][0])
    return menus


def gtk_build(reg):
    menus, actions, ids = gtk_menus(reg), gtk_actions(reg), {}
    counter = [0]

    def nxt():
        counter[0] += 1
        return counter[0]

    def walk(key, depth=0):
        out_items = []
        for it in menus.get(tuple(key), []):
            hw, a = it.get("hidden-when"), actions.get(it.get("action", ""))
            if depth > 8 or (hw == "action-disabled" and a and not a[2]) or (hw == "action-missing" and not a):
                continue
            if ":section" in it:
                kids = walk(it[":section"], depth + 1)
                if kids and out_items and not out_items[-1]["sep"]:
                    out_items.append({"id": nxt(), "label": "", "enabled": False, "sep": True, "toggle": "",
                                      "state": -1, "shortcut": "", "children": []})
                out_items.extend(kids)
                continue
            iid = nxt()
            act = it.get("action")
            info = actions.get(act) if act else None
            toggle, state = "", -1
            target = it.get("target")
            if info and info[3] is not None:
                st = info[3]
                if isinstance(st, bool):
                    toggle, state = "checkmark", int(st)
                elif target is not None:
                    toggle, state = "radio", int(st == target)
            if act:
                ids[iid] = (act, target, info)
            out_items.append({
                "id": iid, "label": clean(it.get("label", "")),
                "enabled": bool(info[2]) if info else (act is None),
                "sep": False, "toggle": toggle, "state": state,
                "shortcut": gtk_accel(it.get("accel", "")),
                "children": walk(it[":submenu"], depth + 1) if ":submenu" in it else [],
            })
        return out_items

    items = walk((0, 0))
    reg["ids"] = ids
    return items


def gtk_activate(reg, iid):
    ent = reg["ids"].get(iid)
    if not ent:
        return
    act, target, info = ent
    if not info:
        return
    params = [target] if target is not None else []
    bus.call(reg["service"], info[0], GTK_ACTIONS, "Activate",
             GLib.Variant("(sava{sv})", (info[1], params, {})), None, Gio.DBusCallFlags.NONE, 2000, None, None, None)


def find(pid):
    """Newest registration owned by `pid`, or by one of its descendants (wrapper scripts)."""
    if pid <= 0:
        return None
    best = None
    for r in regs.values():
        if r["pid"] == pid or pid in ancestors(r["pid"]):
            if best is None or r["seq"] > best["seq"]:
                best = r
    return best or gtk_find(pid)


def clean(label):
    # dbusmenu mnemonics: "_File" -> "File", "__" -> "_"
    out_s, i = "", 0
    while i < len(label):
        c = label[i]
        if c == "_":
            if i + 1 < len(label) and label[i + 1] == "_":
                out_s += "_"
                i += 1
        else:
            out_s += c
        i += 1
    return out_s


def convert(node):
    nid, props, kids = node
    sep = props.get("type") == "separator"
    sc = props.get("shortcut") or []
    names = {"Control": "Ctrl", "Super": "Meta", "Delete": "Del", "Escape": "Esc"}
    shortcut = "+".join(names.get(k, k.upper() if len(k) == 1 else k) for k in sc[0]) if sc and sc[0] else ""
    item = {
        "id": nid,
        "label": clean(props.get("label", "")),
        "enabled": bool(props.get("enabled", True)),
        "sep": sep,
        "toggle": props.get("toggle-type", ""),
        "state": int(props.get("toggle-state", -1)),
        "shortcut": shortcut,
        "children": [convert(k) for k in kids if k[1].get("visible", True)],
    }
    return item


def call(reg, method, params, sig, cb):
    def done(src, res, _):
        try:
            cb(src.call_finish(res))
        except GLib.Error:
            cb(None)
    bus.call(reg["service"], reg["path"], DBUSMENU, method, params, GLib.VariantType(sig),
             Gio.DBusCallFlags.NONE, 2000, None, done, None)


def push(pid):
    reg = find(pid)
    if not reg:
        out({"type": "menu", "pid": pid, "items": []})
        return

    if reg.get("kind") == "gtk":
        out({"type": "menu", "pid": pid, "items": gtk_build(reg)})
        return

    def got(res):
        if res is None:
            out({"type": "menu", "pid": pid, "items": []})
            return
        root = res.unpack()[1]
        items = [convert(k) for k in root[2] if k[1].get("visible", True)]
        out({"type": "menu", "pid": pid, "items": items})

    call(reg, "GetLayout", GLib.Variant("(iias)", (0, -1, [])), "(u(ia{sv}av))", got)


def schedule(pid):
    global pending
    if pending:
        GLib.source_remove(pending)

    def fire():
        global pending
        pending = None
        push(pid)
        return False
    pending = GLib.timeout_add(120, fire)


def on_menu_signal(_c, sender, _p, _i, _s, _params, _u):
    for r in list(regs.values()) + list(gtk_regs.values()):
        if r and r["service"] == sender and find(current) is r:
            schedule(current)
            return


def watch_service(service):
    if service in subs:
        return
    subs[service] = [bus.signal_subscribe(service, DBUSMENU, sig, None, None, Gio.DBusSignalFlags.NONE, on_menu_signal, None)
                     for sig in ("LayoutUpdated", "ItemsPropertiesUpdated")]


def drop_service(service):
    for k in [k for k, r in regs.items() if r["service"] == service]:
        del regs[k]
    gtk_regs.pop(service, None)
    for sid in subs.pop(service, []):
        bus.signal_unsubscribe(sid)
    if current:
        schedule(current)


def on_name_owner(_c, _s, _p, _i, _sig, params, _u):
    name, _old, new = params.unpack()
    if not new and name in subs:
        drop_service(name)


def handle_call(conn, sender, _path, _iface, method, params, inv):
    global seq
    if method == "RegisterWindow":
        wid, mpath = params.unpack()
        seq += 1
        regs[wid] = {"service": sender, "path": mpath, "pid": pid_of(sender), "seq": seq}
        watch_service(sender)
        inv.return_value(None)
        if current:
            schedule(current)
    elif method == "UnregisterWindow":
        regs.pop(params.unpack()[0], None)
        inv.return_value(None)
        if current:
            schedule(current)
    elif method == "GetMenuForWindow":
        r = regs.get(params.unpack()[0])
        if r:
            inv.return_value(GLib.Variant("(so)", (r["service"], r["path"])))
        else:
            inv.return_dbus_error("com.canonical.AppMenu.Registrar.Error", "no menu for window")


inbuf = b""


def run_command(line):
    global current
    parts = line.split()
    try:
        cmd, pid = parts[0], int(parts[1])
        if cmd == "watch":
            current = pid
            push(pid)
        elif cmd in ("show", "click"):
            reg = find(pid)
            iid = int(parts[2])
            if reg and reg.get("kind") == "gtk":
                if cmd == "click":
                    gtk_activate(reg, iid)
            elif reg and cmd == "show":
                call(reg, "AboutToShow", GLib.Variant("(i)", (iid,)), "(b)", lambda res: res and res.unpack()[0] and push(pid))
            elif reg:
                bus.call(reg["service"], reg["path"], DBUSMENU, "Event",
                         GLib.Variant("(isvu)", (iid, "clicked", GLib.Variant("i", 0), 0)),
                         None, Gio.DBusCallFlags.NONE, 2000, None, None, None)
    except (IndexError, ValueError):
        pass


def on_stdin(fd, cond):
    global inbuf
    data = os.read(fd, 4096) if cond & GLib.IOCondition.IN else b""
    if not data:
        loop.quit()
        return False
    inbuf += data
    while b"\n" in inbuf:
        line, inbuf = inbuf.split(b"\n", 1)
        run_command(line.decode("utf-8", "replace"))
    return True


def on_bus_acquired(conn, _name):
    node = Gio.DBusNodeInfo.new_for_xml(REG_XML)
    conn.register_object(REG_PATH, node.interfaces[0], handle_call, None, None)


def on_name_acquired(_c, _n):
    out({"type": "status", "registrar": True})


def on_name_lost(_c, _n):
    # another registrar (e.g. vala-panel-appmenu) owns the name; nothing for us to bridge
    out({"type": "status", "registrar": False})
    loop.quit()


if __name__ == "__main__":
    loop = GLib.MainLoop()
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    bus.signal_subscribe("org.freedesktop.DBus", "org.freedesktop.DBus", "NameOwnerChanged",
                         "/org/freedesktop/DBus", None, Gio.DBusSignalFlags.NONE, on_name_owner, None)
    Gio.bus_own_name_on_connection(bus, REG_NAME, Gio.BusNameOwnerFlags.DO_NOT_QUEUE, on_name_acquired, on_name_lost)
    on_bus_acquired(bus, REG_NAME)
    GLib.io_add_watch(sys.stdin.fileno(), GLib.IOCondition.IN | GLib.IOCondition.HUP | GLib.IOCondition.ERR, on_stdin)
    try:
        loop.run()
    except KeyboardInterrupt:
        pass
