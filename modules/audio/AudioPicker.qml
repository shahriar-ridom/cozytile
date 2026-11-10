import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../services"
import "../../components"

// Output device picker + mic toggle, dropped from the bar's volume item.
PanelWindow {
    id: win
    screen: UiState.focusedScreen
    visible: UiState.audioPicker || card.opacity > 0.01
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "cozytile-audio"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: UiState.audioPicker ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    MouseArea { anchors.fill: parent; onClicked: UiState.audioPicker = false }
    // false at creation, then follows the open state, so the open animation still plays
    // when the window is created already open (see the LazyLoader in shell.qml)
    property bool shown: false
    Component.onCompleted: shown = Qt.binding(() => UiState.audioPicker)

    Rectangle {
        id: card
        width: 300
        height: list.contentHeight + 110
        x: parent.width - width - Theme.barMarginSide - 120
        y: Theme.barMarginTop + Theme.barHeight + 12
        radius: Theme.radius + 2
        color: Theme.popupBg
        border.width: 1; border.color: Theme.border
        opacity: win.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
        MouseArea { anchors.fill: parent }
        Shadowed { target: card; z: -1 }
        focus: true
        Keys.onEscapePressed: UiState.audioPicker = false

        Text { id: title; x: 16; y: 14; text: "Audio output"; color: Theme.text
            font.family: Theme.font; font.pixelSize: Theme.fontLarge; font.bold: true }
        ListView {
            id: list
            anchors { top: title.bottom; left: parent.left; right: parent.right; margins: 10; topMargin: 10 }
            height: contentHeight; interactive: false; spacing: 2
            model: AudioService.sinks
            delegate: Rectangle {
                required property var modelData
                readonly property bool cur: AudioService.sink && AudioService.sink.id === modelData.id
                width: list.width; height: 34; radius: Theme.radiusSmall + 2
                color: cur ? Theme.surfaceHigh : (m.containsMouse ? Theme.hover : "transparent")
                Glyph { x: 10; anchors.verticalCenter: parent.verticalCenter; text: cur ? "" : ""; color: Theme.accent; width: 14; size: 11 }
                Text { x: 32; width: parent.width - 42; anchors.verticalCenter: parent.verticalCenter
                    text: modelData.description || modelData.nickname || modelData.name
                    elide: Text.ElideRight; color: cur ? Theme.text : Theme.textDim
                    font.family: Theme.font; font.pixelSize: Theme.fontSize }
                MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: AudioService.setSink(modelData) }
            }
        }
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 10 }
            height: 38; radius: Theme.radiusSmall + 2
            color: mm.containsMouse ? Theme.hover : Theme.surfaceAlt
            Glyph { x: 12; anchors.verticalCenter: parent.verticalCenter; size: 13
                text: AudioService.micMuted ? "" : ""
                color: AudioService.micMuted ? Theme.bad : Theme.good }
            Text { x: 36; anchors.verticalCenter: parent.verticalCenter
                text: !AudioService.hasMic ? "No microphone" : AudioService.micMuted ? "Microphone muted" : "Microphone live"
                color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontSize }
            MouseArea { id: mm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: AudioService.toggleMic() }
        }
    }
}
