pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../config"

// macOS-style global menu: the focused app's menu bar, exported over D-Bus (com.canonical.dbusmenu).
// scripts/globalmenu.py registers as the session's AppMenu registrar and bridges the menus to us.
// Runs only while Settings.globalMenu is on.
Singleton {
    id: root

    readonly property bool enabled: Settings.globalMenu
    readonly property var toplevel: Hyprland.activeToplevel
    readonly property int pid: toplevel && toplevel.lastIpcObject && toplevel.lastIpcObject.pid ? toplevel.lastIpcObject.pid : 0

    // menu of the focused window: [{ id, label, enabled, sep, toggle, state, shortcut, children }]
    property var items: []
    property bool registrar: true      // false when another AppMenu registrar already owns the bus name
    readonly property bool hasMenu: items.length > 0

    onPidChanged: watch()
    onEnabledChanged: if (!enabled) items = []

    function watch() {
        if (!proc.running) return;
        items = [];
        proc.write("watch " + pid + "\n");
    }
    // ask the app to populate a (sub)menu before it is shown
    function aboutToShow(id) { if (proc.running) proc.write("show " + pid + " " + id + "\n"); }
    function activate(id) { if (proc.running) proc.write("click " + pid + " " + id + "\n"); }

    // the toplevel's pid arrives with its IPC object; make sure it is fetched
    Connections {
        target: Hyprland
        function onActiveToplevelChanged() { if (root.enabled && !root.pid) Hyprland.refreshToplevels(); }
    }

    Process {
        id: proc
        running: root.enabled
        command: ["python3", Quickshell.shellPath("scripts/globalmenu.py")]
        stdinEnabled: true
        onRunningChanged: if (running) { root.registrar = true; root.watch(); }
        stdout: SplitParser {
            onRead: line => {
                let m;
                try { m = JSON.parse(line); } catch (e) { return; }
                if (m.type === "status") root.registrar = m.registrar;
                else if (m.type === "menu" && m.pid === root.pid) root.items = m.items;
            }
        }
    }
}
