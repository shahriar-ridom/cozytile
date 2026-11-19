import QtQuick
import Quickshell
import Quickshell.Io
import "../../config"
import "../../services"
import "../../components"

// System monitor: CPU, memory and temperature (SystemMonitor, with history), disk use and network speed.
// Sampling runs only while the panel is open.
Column {
    id: root

    property var host
    readonly property bool active: host ? host.open : false
    property var disks: []                 // { mount, used, size }
    property real down: 0                  // bytes / s
    property real up: 0
    property var _net: null

    width: 320
    spacing: 10

    property bool counted: false
    onActiveChanged: sync()
    function sync() {
        if (active && !counted) { SystemMonitor.watchers++; counted = true; }
        else if (!active && counted) { SystemMonitor.watchers--; counted = false; }
        if (active) { diskProc.running = true; _net = null; }
    }
    Component.onCompleted: sync()
    Component.onDestruction: if (counted) SystemMonitor.watchers--

    function bytes(n) {
        const u = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (n >= 1024 && i < u.length - 1) { n /= 1024; ++i; }
        return (n < 10 && i > 0 ? n.toFixed(1) : Math.round(n)) + " " + u[i];
    }

    Process {
        id: diskProc
        command: ["df", "-B1", "--output=source,target,used,size", "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs", "-x", "squashfs", "-x", "overlay"]
        stdout: StdioCollector {
            onStreamFinished: {
                // one row per filesystem (btrfs subvolumes share one), under its shortest mount point
                const seen = {};
                root.disks = text.split("\n").slice(1).map(l => l.trim().split(/\s+/)).filter(f => f.length === 4 && !f[1].startsWith("/boot")
                    && !f[1].startsWith("/run") && Number(f[3]) > 0).sort((a, b) => a[1].length - b[1].length)
                    .filter(f => seen[f[0]] ? false : (seen[f[0]] = true)).map(f => ({ mount: f[1], used: Number(f[2]), size: Number(f[3]) })).slice(0, 4);
            }
        }
    }
    FileView { id: netFile; path: "/proc/net/dev"; onLoaded: root.sampleNet(text()) }
    Timer { interval: 1000; repeat: true; running: root.active; onTriggered: netFile.reload() }
    function sampleNet(t) {
        let rx = 0, tx = 0;
        for (const l of t.split("\n").slice(2)) {
            const m = l.trim().match(/^(\S+):\s*(\d+)(?:\s+\d+){7}\s+(\d+)/);
            if (m && m[1] !== "lo") { rx += Number(m[2]); tx += Number(m[3]); }
        }
        const now = Date.now();
        if (_net) { const dt = (now - _net.t) / 1000; if (dt > 0) { down = Math.max(0, (rx - _net.rx) / dt); up = Math.max(0, (tx - _net.tx) / dt); } }
        _net = { rx: rx, tx: tx, t: now };
    }

    Text {
        x: 4
        text: "System"
        color: Theme.text
        font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true
    }

    // one metric: label, value and a history graph
    component Metric: Item {
        property string label
        property string value
        property var series: []
        property color tint: Theme.accent
        width: root.width; height: 54
        Text { x: 4; text: parent.label; color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1 }
        Text { anchors.right: parent.right; anchors.rightMargin: 4; text: parent.value; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
        Sparkline { y: 18; width: parent.width; height: 34; values: parent.series; lineColor: parent.tint }
    }

    Metric { label: "CPU"; value: Math.round(SystemMonitor.cpu * 100) + "%"; series: SystemMonitor.cpuHist; tint: Theme.accent }
    Metric {
        label: "Memory"
        value: root.bytes(SystemMonitor.memUsed) + " / " + root.bytes(SystemMonitor.memTotal)
        series: SystemMonitor.memHist; tint: Theme.warn
    }
    Metric {
        visible: SystemMonitor.hasTemp
        label: "Temperature"; value: Math.round(SystemMonitor.tempC) + "°C"
        series: SystemMonitor.tempHist; tint: Theme.wsUrgent
    }

    // disks
    Repeater {
        model: root.disks
        Item {
            id: d
            required property var modelData
            width: root.width; height: 30
            Text { x: 4; text: d.modelData.mount; color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1 }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 4
                text: root.bytes(d.modelData.used) + " / " + root.bytes(d.modelData.size)
                color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1
            }
            Rectangle {
                y: 18; width: parent.width; height: 5; radius: 3
                color: Theme.hover
                Rectangle {
                    width: parent.width * d.modelData.used / d.modelData.size; height: parent.height; radius: 3
                    color: d.modelData.used / d.modelData.size > 0.9 ? Theme.wsUrgent : Theme.accent
                }
            }
        }
    }

    // network
    Item {
        width: root.width; height: 20
        Text { x: 4; text: NetworkService.name; color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1 }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 4
            text: "↓ " + root.bytes(root.down) + "/s   ↑ " + root.bytes(root.up) + "/s"
            color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1
        }
    }
}
