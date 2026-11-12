pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Recently opened apps and files for the logo menu.
// Apps: every new Hyprland window is recorded (by class, deduplicated, newest first) and persisted.
// Files: read from the freedesktop recent-files list each time the menu opens.
Singleton {
    id: root

    readonly property int maxApps: 8
    readonly property int maxFiles: 8
    property var apps: []      // [{ cls, name }]
    property var files: []     // [{ path, name }]

    function launchApp(cls) {
        const de = DesktopEntries.heuristicLookup(cls);
        if (de) de.execute();
    }
    function openFile(path) { Quickshell.execDetached(["xdg-open", path]); }
    function refreshFiles() { filesProc.running = true; }

    function _record(cls) {
        if (!cls) return;
        const de = DesktopEntries.heuristicLookup(cls);
        if (!de || de.noDisplay) return;        // skip windows with no launchable app (dialogs, shell panels)
        const rest = apps.filter(a => a.cls.toLowerCase() !== cls.toLowerCase());
        apps = [{ cls: cls, name: de.name }].concat(rest).slice(0, maxApps);
        save.restart();
    }

    Connections {
        target: Hyprland
        // openwindow>>ADDRESS,WORKSPACE,CLASS,TITLE (the title may contain commas)
        function onRawEvent(ev) {
            if (ev.name !== "openwindow") return;
            _record(ev.data.split(",")[2] || "");
        }
    }

    FileView {
        id: store
        path: Quickshell.env("HOME") + "/.local/state/cozytile/recent-apps.json"
        blockLoading: true
        printErrors: false
    }
    Timer { id: save; interval: 600; onTriggered: store.setText(JSON.stringify(root.apps)) }
    Component.onCompleted: {
        try { const a = JSON.parse(store.text()); if (Array.isArray(a)) apps = a.slice(0, maxApps); } catch (e) {}
    }

    Process {
        id: filesProc
        command: [Quickshell.shellPath("scripts/recent-files.py"), String(root.maxFiles)]
        stdout: StdioCollector {
            onStreamFinished: { try { root.files = JSON.parse(text); } catch (e) { root.files = []; } }
        }
    }
}
