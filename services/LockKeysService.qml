pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Caps / Num / Scroll lock state. Wayland has no lock-key event for clients, so Hyprland binds on the lock
// keys call `ipc call keys refresh` (see dotfiles/hypr/binds.lua); we then read the compositor's state once.
Singleton {
    id: root
    property bool caps: false
    property bool num: false
    property bool scroll: false
    property bool known: false

    function refresh() { if (!reader.running) reader.running = true; }

    function _apply(c, n, s) {
        const first = !known;
        const changes = [];
        if (c !== caps) changes.push(["caps", "Caps Lock", c]);
        if (n !== num) changes.push(["num", "Num Lock", n]);
        if (s !== scroll) changes.push(["scroll", "Scroll Lock", s]);
        caps = c; num = n; scroll = s; known = true;
        if (first) return;                      // initial read: no hint
        for (const ch of changes)
            ActivityService.post("lock-" + ch[0], "toast", {
                glyph: ch[2] ? "" : "", text: ch[1] + (ch[2] ? " on" : " off"),
                tone: ch[2] ? "warn" : "dim", priority: 45, ms: 1800 });
    }

    // hyprctl reports the main keyboard's xkb state; scroll lock is only exposed as a kernel LED
    Process {
        id: reader
        command: ["sh", "-c", "hyprctl devices -j; echo @@; cat /sys/class/leds/*::scrolllock/brightness 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("@@");
                try {
                    const kb = JSON.parse(parts[0]).keyboards;
                    const main = kb.find(k => k.main) || kb[0];
                    const sl = (parts[1] || "").split("\n").some(l => l.trim() === "1");
                    root._apply(!!main.capsLock, !!main.numLock, sl);
                } catch (e) { /* hyprctl unavailable: keep last state */ }
            }
        }
    }
    // Fallback when a bind does not fire: watch the keyboard LEDs (tiny sysfs reads, 1 Hz) and re-read the real
    // state only when an LED actually changes. Paths are discovered once.
    property var ledPaths: []
    property string _sig: ""
    Process {
        running: true
        command: ["sh", "-c", "ls /sys/class/leds/*::capslock/brightness /sys/class/leds/*::numlock/brightness /sys/class/leds/*::scrolllock/brightness 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: root.ledPaths = text.split("\n").filter(l => l.length) }
    }
    property var _vals: ({})
    Instantiator {
        id: ledWatch
        model: root.ledPaths
        delegate: FileView {
            required property string modelData
            path: modelData
            onLoaded: {
                root._vals[modelData] = text().trim();
                const sig = Object.keys(root._vals).sort().map(k => root._vals[k]).join("");
                if (root._sig !== "" && sig !== root._sig) root.refresh();
                root._sig = sig;
            }
        }
        onObjectAdded: (i, o) => o.reload()
    }
    Timer {
        interval: 1000; repeat: true; running: root.ledPaths.length > 0
        onTriggered: { for (let i = 0; i < ledWatch.count; i++) ledWatch.objectAt(i).reload(); }
    }
    Component.onCompleted: refresh()
}
