pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screen / keyboard backlight through brightnessctl (only when hardware exists; desktops get no OSD).
Singleton {
    id: root
    property string _kind: "brightness"

    function change(kind, delta) {   // kind: "brightness" | "kbd"; delta: percent, may be negative
        if (run.running) return;
        _kind = kind;
        const dev = kind === "kbd" ? ["-d", "*kbd_backlight*"] : ["-c", "backlight"];
        const step = Math.abs(delta) + "%" + (delta < 0 ? "-" : "+");
        run.command = ["brightnessctl", ...dev, "-m", "set", step];
        run.running = true;
    }

    Process {
        id: run
        stdout: StdioCollector {
            onStreamFinished: {
                // machine format: device,class,current,percent%,max
                const f = text.trim().split(",");
                const pct = parseInt(f[3]);
                if (!isNaN(pct)) UiState.osd(root._kind, pct / 100, false);
            }
        }
    }
}
