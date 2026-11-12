#!/usr/bin/env python3
"""Global menu bridge for the cozytile bar.

Acts as the session's com.canonical.AppMenu.Registrar (what Qt, GTK-module, Firefox, ... talk to
when an app has a menu bar to export), then reads the menu of the focused app over
com.canonical.dbusmenu and forwards it to the shell.

stdin  (one command per line)
    watch <pid>              follow the menu of the window owned by <pid> (0 = none)
    show <pid> <id>          AboutToShow for an item, then refresh (call before opening a submenu)
    click <pid> <id>         activate an item
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


def find(pid):
    """Newest registration owned by `pid`, or by one of its descendants (wrapper scripts)."""
    if pid <= 0:
        return None
    best = None
    for r in regs.values():
        if r["pid"] == pid or pid in ancestors(r["pid"]):
            if best is None or r["seq"] > best["seq"]:
                best = r
    return best


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
    for r in regs.values():
        if r["service"] == sender and find(current) is r:
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
            if reg and cmd == "show":
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
