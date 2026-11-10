pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// CPU / RAM / temperature. One timer, procfs/sysfs reads only (no child processes while idle).
// Extra detail (top processes, all hwmon sensors) is fetched only while a stat popup is open.
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
    property int interval: Settings.statsInterval
    readonly property int histLen: 60

    // rolling history for the popup graphs (oldest first)
    property var cpuHist: []
    property var memHist: []
    property var tempHist: []
    property real load1: 0
    property real memCached: 0
    property real swapUsed: 0
    property real swapTotal: 0
    property int cores: 1
    // popup detail: [{name, value, mem}] top processes, [{name, c}] sensors
    property var topProcs: []
    property var sensors: []
    // which popup wants detail: "" | cpu | ram | temp
    readonly property string detail: UiState.statPopup

    function _push(arr, v) { const a = arr.concat([v]); return a.length > histLen ? a.slice(a.length - histLen) : a; }

    property var _prev: null
    property string _tempPath: ""

    function _tick() {
        stat.reload();
        meminfo.reload();
        if (_tempPath) temp.reload();
        loadavg.reload();
        if (detail !== "") _refreshDetail();
    }
    function _refreshDetail() {
        if (detail !== "temp" && !topProc.running) topProc.running = true;
        if (detail === "temp" && !sensorProc.running) sensorProc.running = true;
    }
    onDetailChanged: if (detail !== "") _refreshDetail()

    Timer {
        interval: root.interval
        repeat: true
        running: root.watchers > 0 || root.detail !== ""
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
                if (dt > 0) { root.cpu = Math.max(0, Math.min(1, 1 - di / dt)); root.cpuHist = root._push(root.cpuHist, root.cpu); }
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
            root.memCached = kb("Cached");
            root.swapTotal = kb("SwapTotal");
            root.swapUsed = root.swapTotal - kb("SwapFree");
            root.memHist = root._push(root.memHist, root.mem);
        }
    }

    FileView {
        id: temp
        path: root._tempPath
        onLoaded: { root.tempC = Number(text().trim()) / 1000; root.tempHist = root._push(root.tempHist, root.tempC); }
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

    FileView {
        id: loadavg
        path: "/proc/loadavg"
        onLoaded: root.load1 = Number(text().split(" ")[0]) || 0
    }

    Process {
        id: coreCount
        running: true
        command: ["nproc"]
        stdout: StdioCollector { onStreamFinished: root.cores = parseInt(text) || 1 }
    }

    // Top consumers. CPU needs two samples (top's first frame is since-boot), RAM is a plain ps.
    Process {
        id: topProc
        command: root.detail === "ram"
            ? ["sh", "-c", "ps -eo rss=,comm= --sort=-rss | head -6"]
            : ["sh", "-c", "top -bn2 -d 0.4 -w 512 -o %CPU | awk '/^top -/{n++} n==2' | awk '/PID/{f=1;next} f' | head -5 | awk '{print $9, $NF}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const ram = root.detail === "ram";
                root.topProcs = text.trim().split("\n").filter(l => l.trim()).map(l => {
                    const t = l.trim().split(/\s+/);
                    const n = Number(t.shift().replace(",", "."));
                    return { name: t.join(" "), value: ram ? n * 1024 : n };
                });
            }
        }
    }

    // Every hwmon chip's first temperature (CPU, NVMe, GPU, ...).
    Process {
        id: sensorProc
        command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do t=$(cat $d/temp1_input 2>/dev/null) && echo \"$(cat $d/name) $t\"; done"]
        stdout: StdioCollector {
            onStreamFinished: root.sensors = text.trim().split("\n").filter(l => l.trim()).map(l => {
                const t = l.trim().split(" ");
                return { name: t[0], c: Number(t[1]) / 1000 };
            })
        }
    }
}
