pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// CPU / RAM / temperature. One timer, procfs/sysfs reads only (no child processes while idle).
Singleton {
    id: root

    property real cpu: 0            // 0..1
    property real memUsed: 0        // bytes
    property real memTotal: 0       // bytes
    readonly property real mem: memTotal > 0 ? memUsed / memTotal : 0
    property real tempC: -1         // < 0 when unavailable
    readonly property bool hasTemp: tempC >= 0
    // Only tick while something actually shows the stats (bar sets this).
    property int watchers: 0
    property int interval: 2000

    property var _prev: null
    property string _tempPath: ""

    function _tick() {
        stat.reload();
        meminfo.reload();
        if (_tempPath) temp.reload();
    }

    Timer {
        interval: root.interval
        repeat: true
        running: root.watchers > 0
        triggeredOnStart: true
        onTriggered: root._tick()
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const line = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = line[3] + (line[4] || 0);
            const total = line.reduce((a, b) => a + b, 0);
            if (root._prev) {
                const dt = total - root._prev.total;
                const di = idle - root._prev.idle;
                if (dt > 0) root.cpu = Math.max(0, Math.min(1, 1 - di / dt));
            }
            root._prev = { total: total, idle: idle };
        }
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const t = text();
            const kb = k => { const m = t.match(new RegExp("^" + k + ":\\s+(\\d+)", "m")); return m ? Number(m[1]) * 1024 : 0; };
            root.memTotal = kb("MemTotal");
            root.memUsed = root.memTotal - kb("MemAvailable");
        }
    }

    FileView {
        id: temp
        path: root._tempPath
        onLoaded: root.tempC = Number(text().trim()) / 1000
    }

    // Find the CPU temperature sensor once (k10temp = AMD, coretemp = Intel, zenpower).
    Process {
        id: findTemp
        running: true
        command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do case \"$(cat $d/name 2>/dev/null)\" in k10temp|coretemp|zenpower|cpu_thermal) echo $d/temp1_input; break;; esac; done"]
        stdout: StdioCollector {
            onStreamFinished: root._tempPath = text.trim()
        }
    }
}
