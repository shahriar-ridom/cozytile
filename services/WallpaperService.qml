pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// Scans wallpaper directories, applies wallpapers (per monitor), remembers them, restores at start.
Singleton {
    id: root

    property var files: []          // absolute paths
    property bool scanning: false
    readonly property string script: Quickshell.shellPath("scripts/wallpaper.sh")
    signal applied(string monitor, string path)

    function expand(d) { return d.startsWith("~") ? Quickshell.env("HOME") + d.slice(1) : d; }

    function current(monitor) {
        const w = Settings.wallpapers || {};
        return w[monitor] || w["*"] || "";
    }

    // monitor "" = all outputs
    function set(path, monitor) {
        const w = Object.assign({}, Settings.wallpapers || {});
        if (!monitor) { for (const k of Object.keys(w)) delete w[k]; w["*"] = path; }
        else w[monitor] = path;
        Settings.wallpapers = w;
        Settings.save();
        Quickshell.execDetached([script, path, monitor || ""]);
        applied(monitor || "*", path);
        if (Settings.wallpaperTheming) ThemeService.generate(path);
    }

    function scan() {
        if (scanner.running) return;
        scanning = true;
        scanner.command = ["find", "-L", ...Settings.wallpaperDirs.map(expand), "-maxdepth", "3", "-type", "f",
            "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", "-o", "-iname", "*.gif", ")"];
        scanner.running = true;
    }

    Process {
        id: scanner
        stdout: StdioCollector {
            onStreamFinished: {
                root.files = text.split("\n").filter(l => l.length).sort();
                root.scanning = false;
            }
        }
        onExited: root.scanning = false
    }

    // Restore remembered wallpapers once settings are loaded.
    property bool _restored: false
    Connections {
        target: Settings
        function onLoadedChanged() { root._tryRestore(); }
    }
    Component.onCompleted: _tryRestore()
    function _tryRestore() {
        if (_restored || !Settings.loaded) return;
        _restored = true;
        const w = Settings.wallpapers || {};
        for (const k of Object.keys(w)) Quickshell.execDetached([script, w[k], k === "*" ? "" : k]);
    }
}
