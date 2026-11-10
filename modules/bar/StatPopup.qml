import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../services"
import "../../components"

// CPU / RAM / temperature detail card, dropped from the matching bar item.
PanelWindow {
    id: win
    screen: UiState.focusedScreen
    visible: UiState.statPopup !== "" || card.opacity > 0.01
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "cozytile-stats"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: UiState.statPopup !== "" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: UiState.statPopup = "" }

    // keep content while fading out
    property string kind: "cpu"
    Connections { target: UiState; function onStatPopupChanged() { if (UiState.statPopup !== "") win.kind = UiState.statPopup; } }

    readonly property bool isCpu: kind === "cpu"
    readonly property bool isRam: kind === "ram"
    readonly property bool isTemp: kind === "temp"
    readonly property real cur: isCpu ? SystemMonitor.cpu : isRam ? SystemMonitor.mem : SystemMonitor.tempC
    readonly property color tone: isTemp ? (cur > 85 ? Theme.bad : cur > 70 ? Theme.caution : Theme.accent)
                                         : (cur > 0.9 ? Theme.bad : cur > 0.75 ? Theme.caution : Theme.accent)
    function gb(b) { return (b / 1073741824).toFixed(1) + " GB"; }

    Rectangle {
        id: card
        width: 300
        height: col.implicitHeight + 28
        x: Math.max(8, Math.min(parent.width - width - 8, UiState.statPopupX - width / 2))
        y: Theme.barMarginTop + Theme.barHeight + 12
        radius: Theme.radius + 2
        color: Theme.popupBg
        border.width: 1; border.color: Theme.border
        opacity: UiState.statPopup !== "" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
        Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent }
        Shadowed { target: card; z: -1 }
        focus: true
        Keys.onEscapePressed: UiState.statPopup = ""

        Column {
            id: col
            x: 16; y: 14
            width: parent.width - 32
            spacing: 12

            // header: icon, title, big value
            Item {
                width: parent.width; height: 34
                Glyph { id: hIcon; size: 16; color: win.tone; anchors.verticalCenter: parent.verticalCenter
                    text: win.isCpu ? "\uf2db" : win.isRam ? "\uf538" : "\uf2c9" }
                Text { x: 26; anchors.verticalCenter: parent.verticalCenter
                    text: win.isCpu ? "Processor" : win.isRam ? "Memory" : "Temperature"
                    color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontLarge; font.bold: true }
                Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: win.isTemp ? Math.round(win.cur) + "°C" : Math.round(win.cur * 100) + "%"
                    color: win.tone; font.family: Theme.font; font.pixelSize: Theme.fontTitle + 4; font.bold: true }
            }

            Sparkline {
                width: parent.width; height: 56
                samples: SystemMonitor.histLen
                values: win.isCpu ? SystemMonitor.cpuHist : win.isRam ? SystemMonitor.memHist : SystemMonitor.tempHist
                maxValue: win.isTemp ? 100 : 1
                lineColor: win.tone
            }

            // facts
            Column {
                width: parent.width; spacing: 6
                visible: !win.isTemp
                Repeater {
                    model: win.isCpu ? [
                        { k: "Load (1 min)", v: SystemMonitor.load1.toFixed(2) },
                        { k: "Cores", v: String(SystemMonitor.cores) }
                    ] : [
                        { k: "Used", v: win.gb(SystemMonitor.memUsed) + " / " + win.gb(SystemMonitor.memTotal) },
                        { k: "Cached", v: win.gb(SystemMonitor.memCached) },
                        { k: "Swap", v: SystemMonitor.swapTotal > 0 ? win.gb(SystemMonitor.swapUsed) + " / " + win.gb(SystemMonitor.swapTotal) : "none" }
                    ]
                    delegate: Item {
                        required property var modelData
                        width: col.width; height: 16
                        Text { text: modelData.k; color: Theme.textDim; font.family: Theme.font; font.pixelSize: Theme.fontSize }
                        Text { anchors.right: parent.right; text: modelData.v; color: Theme.text
                            font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                    }
                }
            }

            // temperature: all sensors
            Column {
                width: parent.width; spacing: 8
                visible: win.isTemp
                Repeater {
                    model: SystemMonitor.sensors
                    delegate: Item {
                        required property var modelData
                        width: col.width; height: 28
                        Text { text: modelData.name; color: Theme.textDim; font.family: Theme.font; font.pixelSize: Theme.fontSize }
                        Text { anchors.right: parent.right; text: Math.round(modelData.c) + "°C"
                            color: modelData.c > 85 ? Theme.bad : modelData.c > 70 ? Theme.caution : Theme.text
                            font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                        Rectangle { y: 20; width: parent.width; height: 4; radius: 2; color: Theme.surfaceHigh
                            Rectangle { width: parent.width * Math.min(1, modelData.c / 100); height: parent.height; radius: 2
                                color: modelData.c > 85 ? Theme.bad : modelData.c > 70 ? Theme.caution : Theme.accent } }
                    }
                }
            }

            // top processes
            Column {
                width: parent.width; spacing: 4
                visible: !win.isTemp && SystemMonitor.topProcs.length > 0
                Rectangle { width: parent.width; height: 1; color: Theme.border }
                Item { width: parent.width; height: 8 }
                Text { text: "TOP PROCESSES"; color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.fontSmall; font.bold: true; font.letterSpacing: 1 }
                Repeater {
                    model: SystemMonitor.topProcs
                    delegate: Item {
                        required property var modelData
                        width: col.width; height: 18
                        Text { width: parent.width - 70; elide: Text.ElideRight; text: modelData.name
                            color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontSize }
                        Text { anchors.right: parent.right
                            text: win.isCpu ? modelData.value.toFixed(1) + "%" : win.gb(modelData.value)
                            color: Theme.textDim; font.family: Theme.font; font.pixelSize: Theme.fontSize }
                    }
                }
            }
        }
    }
}
