import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../services"
import "../../components"

// Transient pill at the bottom centre. Shows volume / mic / brightness / keyboard backlight.
PanelWindow {
    id: win
    screen: UiState.focusedScreen
    visible: pill.opacity > 0.01 && !UiState.islandActive   // the island shows these when it exists
    color: "transparent"
    anchors { bottom: true }
    margins { bottom: 70 }
    implicitWidth: 280
    implicitHeight: 62
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "cozytile-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    mask: Region {}   // never takes input

    property string kind: "volume"
    property real value: 0
    property bool muted: false
    property bool shown: false

    function show(k, v, m) {
        kind = k; value = v; muted = m; shown = true; hideTimer.restart();
    }
    Timer { id: hideTimer; interval: Settings.osdTimeout; onTriggered: win.shown = false }
    Connections { target: AudioService; function onOsd(k, v, m) { win.show(k, v, m); } }
    Connections { target: UiState; function onOsd(k, v, m) { win.show(k, v, m); } }

    readonly property string glyph: {
        if (kind === "mic") return muted ? "" : "";
        if (kind === "brightness") return "";
        if (kind === "kbd") return "";
        return muted || value <= 0 ? "" : value < 0.5 ? "" : "";
    }
    readonly property real shownValue: muted ? 0 : Math.min(1, value)

    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: 260; height: 46; radius: height / 2
        color: Theme.osdBg
        border.width: 1; border.color: Theme.border
        opacity: win.shown ? 1 : 0
        scale: win.shown ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
        Shadowed { target: pill; z: -1 }

        Glyph { x: 18; anchors.verticalCenter: parent.verticalCenter; size: 16
            text: win.glyph; color: win.muted ? Theme.textMuted : Theme.accent; width: 20 }
        Rectangle {
            id: track
            x: 52; width: parent.width - 52 - 58; height: 6; radius: 3
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.osdTrack
            Rectangle {
                height: parent.height; radius: 3
                width: parent.width * win.shownValue
                color: win.muted ? Theme.textMuted : Theme.osdFill
                Behavior on width { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
            }
        }
        Text {
            anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
            text: win.muted ? "mute" : Math.round(win.value * 100) + "%"
            color: Theme.text
            font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true
        }
    }
}
