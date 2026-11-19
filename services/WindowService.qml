pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../config"

// Hyprland windows grouped by app, for the dock. A group's key is its desktop entry id when the window class resolves
// to one (so it matches a pinned id), otherwise the lowercased class. Window geometry (lastIpcObject) is refreshed on
// every Hyprland event, and polled while the dock hides intelligently (floating moves and resizes send no event).
Singleton {
    id: root

    // window classes that don't resolve to their desktop entry on their own: class (lowercase) -> desktop entry id
    readonly property var classMap: ({
        "code-url-handler": "code",
        "jetbrains-idea": "jetbrains-idea",
        "brave-browser": "brave-browser",
        "org.wezfurlong.wezterm": "org.wezfurlong.wezterm"
    })

    function classOf(t) {
        const o = t ? t.lastIpcObject : null;
        return (o && o["class"]) || (t && t.wayland ? t.wayland.appId : "") || "";
    }
    // variants such as "kitty-floating" (a scratchpad terminal) fall back to the part before the first dash
    function entryFor(cls) {
        if (!cls) return null;
        const c = cls.toLowerCase();
        const head = c.indexOf("-") > 0 ? c.slice(0, c.indexOf("-")) : "";
        return (classMap[c] ? DesktopEntries.byId(classMap[c]) : null)
            ?? DesktopEntries.byId(cls) ?? DesktopEntries.byId(c) ?? DesktopEntries.heuristicLookup(cls)
            ?? (head ? DesktopEntries.byId(head) : null);
    }

    // [{ key, cls, entry, windows: [HyprlandToplevel] }] in order of first appearance
    readonly property var groups: {
        DesktopEntries.applications.values.length;
        const out = [];
        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject;
            if (o && o.mapped === false) continue;
            const cls = classOf(t);
            if (!cls) continue;
            const e = entryFor(cls);
            const key = e ? e.id : cls.toLowerCase();
            const g = out.find(x => x.key === key);
            if (g) g.windows.push(t);
            else out.push({ key: key, cls: cls, entry: e, windows: [t] });
        }
        return out;
    }

    // true when a fullscreen window is shown on the screen's visible workspaces (a game, when `game` is set and its class looks like one)
    readonly property var gameClass: /^(steam_app_|gamescope|lutris|heroic|minecraft|org\.prismlauncher|.*\.exe$)/i
    function fullscreenOn(screen, game) {
        const m = screen ? Hyprland.monitorFor(screen) : null;
        if (!m || !m.activeWorkspace) return false;
        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject;
            if (!o || !o.fullscreen || o.mapped === false || !o.workspace || o.workspace.id !== m.activeWorkspace.id) continue;
            if (!game || gameClass.test(classOf(t))) return true;
        }
        return false;
    }
    function addr(t) { return "0x" + t.address.replace(/^0x/, ""); }
    function _run(lua, classic) { Hyprland.dispatch(Hyprland.usingLua ? lua : classic); }
    // focusing a window on another workspace switches to it
    function focus(t) { const a = addr(t); _run("hl.dsp.focus({ window = \"address:" + a + "\" })", "focuswindow address:" + a); }
    function close(t) { const a = addr(t); _run("hl.dsp.window.close({ window = \"address:" + a + "\" })", "closewindow address:" + a); }
    function quit(windows) {
        const pids = {};
        for (const t of windows) { const o = t.lastIpcObject; if (o && o.pid > 0) pids[o.pid] = true; }
        const list = Object.keys(pids);
        if (list.length) Quickshell.execDetached(["kill"].concat(list));
        else for (const t of windows) close(t);
    }

    // true when a window on the screen's visible workspaces (normal and special) overlaps the rect, in screen pixels
    function overlaps(screen, rx, ry, rw, rh) {
        const m = screen ? Hyprland.monitorFor(screen) : null;
        if (!m) return false;
        const mo = m.lastIpcObject || {};
        const ids = [];
        if (m.activeWorkspace) ids.push(m.activeWorkspace.id);
        if (mo.specialWorkspace && mo.specialWorkspace.id) ids.push(mo.specialWorkspace.id);
        const mx = mo.x ?? 0, my = mo.y ?? 0;
        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject;
            if (!o || !o.at || !o.size || o.hidden || o.mapped === false) continue;
            if (!o.workspace || ids.indexOf(o.workspace.id) < 0) continue;
            const x = o.at[0] - mx, y = o.at[1] - my;
            if (x < rx + rw && x + o.size[0] > rx && y < ry + rh && y + o.size[1] > ry) return true;
        }
        return false;
    }

    // true while the window's workspace is shown on some monitor (so it is being rendered)
    function onScreen(t) {
        const o = t ? t.lastIpcObject : null;
        const id = o && o.workspace ? o.workspace.id : (t && t.workspace ? t.workspace.id : null);
        if (id === null) return false;
        for (const m of Hyprland.monitors.values) {
            if (m.activeWorkspace && m.activeWorkspace.id === id) return true;
            const mo = m.lastIpcObject;
            if (mo && mo.specialWorkspace && mo.specialWorkspace.id === id) return true;
        }
        return false;
    }

    function refresh() { Hyprland.refreshToplevels(); Hyprland.refreshMonitors(); }
    Connections { target: Hyprland; function onRawEvent(ev) { refreshSoon.restart(); } }
    Timer { id: refreshSoon; interval: 60; onTriggered: root.refresh() }
    Timer {
        interval: 1000; repeat: true
        running: Settings.dockEnabled && Settings.dockHide === "intelli"
        onTriggered: root.refresh()
    }
    Component.onCompleted: refresh()
}
