pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// Clipboard history for the dock's clipboard tool, read from cliphist (the Hyprland startup already runs
// `wl-paste --watch cliphist store`). Pinned entries are plain text kept in Settings.dockClipPinned.
// Entry: { id, text, image }
Singleton {
    id: root

    property var entries: []
    property bool missing: false        // cliphist or wl-copy is not installed

    function refresh() { if (!list.running) list.running = true; }
    function copy(e) { Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", e.id]); }
    function copyText(t) { Quickshell.execDetached(["wl-copy", "--", t]); }
    function clear() { Quickshell.execDetached(["cliphist", "wipe"]); entries = []; }
    function isPinned(t) { return Settings.dockClipPinned.indexOf(t) >= 0; }
    function togglePin(t) {
        Settings.dockClipPinned = isPinned(t) ? Settings.dockClipPinned.filter(x => x !== t) : [t].concat(Settings.dockClipPinned);
    }

    Process {
        id: list
        command: ["sh", "-c", 'command -v cliphist >/dev/null && command -v wl-copy >/dev/null || { echo MISSING; exit 0; }; cliphist list | head -60']
        stdout: StdioCollector {
            onStreamFinished: {
                root.missing = text.startsWith("MISSING");
                root.entries = root.missing ? [] : text.split("\n").filter(l => l.indexOf("\t") > 0).map(l => {
                    const i = l.indexOf("\t"), t = l.slice(i + 1);
                    const m = t.match(/^\[\[ binary data .*?(png|jpe?g|bmp|gif|webp)(?: (\d+x\d+))?/);
                    return { id: l.slice(0, i), text: m ? "Image" + (m[2] ? " " + m[2] : "") + " (" + m[1] + ")" : t, image: !!m };
                });
            }
        }
    }
}
