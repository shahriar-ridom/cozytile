pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../config"

// Stage = workspace. Each Hyprland workspace is a desktop shown in the overview (Mission Control style).
// Hyprland stays the source of truth for windows; only names, icons and app rules are persisted
// (Settings.stage). Switching focuses the workspace; moving a window sends it to another workspace.
// Nothing is ever closed.
Singleton {
    id: root

    readonly property var defaults: ({
        enabled: true,
        side: "left",             // left | right (which edge)
        radius: 12, animSpeed: 1.0,
        notify: true,
        stages: [],               // saved names/icons per workspace id
        rules: []                 // [{ cls: "firefox", stage: "research" }]
    })

    function get(k) { const c = Settings.stage || {}; return c[k] !== undefined ? c[k] : defaults[k]; }
    function set(k, v) {
        const c = Object.assign({}, defaults, Settings.stage || {});
        c[k] = v;
        Settings.stage = c;
        Settings.save();
    }

    readonly property bool enabled: get("enabled")

    // revision bumps on every Hyprland event so bindings over windows re-evaluate
    property int rev: 0

    // A stage IS a Hyprland workspace. The list is every live workspace plus the ones saved here
    // (so named or emptied desktops stay in the sidebar), sorted by id, never empty.
    readonly property var stages: {
        rev;
        const saved = (get("stages") || []).filter(s => typeof s.id === "number");   // drops legacy string ids
        const ids = {};
        for (const s of saved) ids[s.id] = true;
        for (const w of Hyprland.workspaces.values) if (w.id > 0) ids[w.id] = true;
        let list = Object.keys(ids).map(Number).sort((a, b) => a - b);
        if (!list.length) list = [1];
        return list.map(id => saved.find(s => s.id === id) ?? { id: id, name: "Desktop " + id, icon: "" });
    }
    readonly property int defaultId: stages[0].id

    function find(id) { return stages.find(s => s.id === id) ?? null; }
    function indexOf(id) { return stages.findIndex(s => s.id === id); }
    function activeFor(screen) {
        rev;
        const m = screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor;
        const w = m ? m.activeWorkspace : null;
        return w ? w.id : -1;
    }
    readonly property int activeId: activeFor(null)
    function windows(id) {
        rev;
        return Hyprland.toplevels.values.filter(t => t.workspace && t.workspace.id === id);
    }
    function addr(t) { return "0x" + t.address.replace(/^0x/, ""); }
    function byAddr(a) { rev; return Hyprland.toplevels.values.find(t => addr(t) === a) ?? null; }
    function closeWindow(address) { _run("hl.dsp.window.close({ window = \"address:" + address + "\" })", "closewindow address:" + address); refreshSoon.restart(); }
    function windowClass(t) { const o = t ? t.lastIpcObject : null; return (o && o.class) ? o.class : ""; }
    function iconFor(t) {
        const c = windowClass(t);
        const e = c ? (DesktopEntries.heuristicLookup(c) ?? DesktopEntries.byId(c)) : null;
        return e && e.icon ? e.icon : (c ? c.toLowerCase() : "application-x-executable");
    }

    // ---- compositor dispatch (classic and Lua configs) ----
    function _run(lua, classic) { Hyprland.dispatch(Hyprland.usingLua ? lua : classic); }
    function activate(id) {
        if (!find(id)) return;
        _run("hl.dsp.focus({ workspace = " + id + " })", "workspace " + id);
    }
    function moveWindow(address, id) {
        if (!find(id)) return;
        _run("hl.dsp.window.move({ workspace = " + id + ", follow = false, window = \"address:" + address + "\" })",
             "movetoworkspacesilent " + id + ",address:" + address);
        refreshSoon.restart();
    }
    function focusWindow(address) {
        _run("hl.dsp.focus({ window = \"address:" + address + "\" })", "focuswindow address:" + address);
    }
    function moveFocused(id) { const t = Hyprland.activeToplevel; if (t) moveWindow(addr(t), id); }
    function cycle(delta) {
        const n = stages.length;
        if (n < 2) return;
        activate(stages[(Math.max(0, indexOf(activeId)) + delta + n) % n].id);
    }
    function activateIndex(i) { if (i >= 0 && i < stages.length) activate(stages[i].id); }

    // ---- stage management: only names/icons are saved; the workspace itself belongs to Hyprland ----
    function _upsert(id, patch) {
        const saved = (get("stages") || []).slice();
        const i = saved.findIndex(s => s.id === id);
        const cur = i >= 0 ? saved[i] : (find(id) ?? { id: id, name: "Desktop " + id, icon: "" });
        const next = Object.assign({}, cur, patch);
        if (i >= 0) saved[i] = next; else saved.push(next);
        set("stages", saved);
    }
    function create(name, icon) {
        const id = stages[stages.length - 1].id + 1;
        _upsert(id, { name: (name || "").trim() || "Desktop " + id, icon: icon || "" });
        return id;
    }
    function rename(id, name) { const n = (name || "").trim(); if (n) _upsert(id, { name: n }); }
    function setIcon(id, icon) { _upsert(id, { icon: icon }); }
    // windows of a removed desktop move to the first remaining one; nothing is closed
    function remove(id) {
        if (stages.length < 2 || !find(id)) return;
        const to = stages.find(s => s.id !== id).id;
        for (const t of windows(id)) moveWindow(addr(t), to);
        set("rules", (get("rules") || []).filter(r => r.stage !== id));
        set("stages", (get("stages") || []).filter(s => s.id !== id));
        if (activeId === id) activate(to);
    }
    function addRule(cls, id) {
        const c = (cls || "").trim().toLowerCase();
        if (!c || !find(id)) return;
        set("rules", (get("rules") || []).filter(r => r.cls !== c).concat([{ cls: c, stage: id }]));
    }
    function removeRule(cls) { set("rules", (get("rules") || []).filter(r => r.cls !== cls)); }
    function ruleFor(cls) {
        const c = (cls || "").toLowerCase();
        const r = (get("rules") || []).find(x => x.cls === c);
        return r && find(r.stage) ? r.stage : -1;
    }
    function setEnabled(on) { set("enabled", !!on); }

    // ---- window tracking (event driven) ----
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            root.rev++;
            if (!root.enabled || ev.name !== "openwindow") return;
            // data: address,workspace id,class,title. A rule sends the window to its desktop; otherwise it stays where it opened
            const p = ev.data.split(",");
            const rule = root.ruleFor(p[2] || "");
            if (rule >= 0 && Number(p[1]) !== rule && Number(p[1]) > 0) root.moveWindow("0x" + p[0], rule);
        }
    }
    Timer { id: refreshSoon; interval: 120; onTriggered: { Hyprland.refreshToplevels(); Hyprland.refreshWorkspaces(); root.rev++; } }
    Component.onCompleted: { Hyprland.refreshToplevels(); }
}
