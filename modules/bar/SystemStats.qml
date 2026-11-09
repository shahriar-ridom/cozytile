import QtQuick
import "../../config"
import "../../services"

Row {
    id: root
    property bool showTemp: true
    spacing: 0
    // sample CPU/RAM only while this is actually on screen
    property bool counted: false
    function sync() {
        if (visible && !counted) { SystemMonitor.watchers++; counted = true; }
        else if (!visible && counted) { SystemMonitor.watchers--; counted = false; }
    }
    onVisibleChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: { if (counted) SystemMonitor.watchers--; }

    StatItem {
        icon: ""
        value: Math.round(SystemMonitor.cpu * 100) + "%"
        iconColor: SystemMonitor.cpu > 0.85 ? Theme.bad : Theme.barTextDim
    }
    StatItem {
        icon: ""
        value: (SystemMonitor.memUsed / 1073741824).toFixed(1) + "G"
        iconColor: SystemMonitor.mem > 0.9 ? Theme.bad : Theme.barTextDim
    }
    StatItem {
        visible: root.showTemp && SystemMonitor.hasTemp
        width: visible ? implicitWidth : 0
        icon: ""
        value: Math.round(SystemMonitor.tempC) + "°"
        iconColor: SystemMonitor.tempC > 85 ? Theme.bad : SystemMonitor.tempC > 70 ? Theme.caution : Theme.barTextDim
    }
}
