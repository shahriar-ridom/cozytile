import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../services"
import "../../components"

// History drawer from the right edge, with DND and clear-all.
PanelWindow {
    id: win
    screen: UiState.focusedScreen
    visible: UiState.notifCenter || panel.x < width
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "cozytile-notification-center"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: UiState.notifCenter ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; onClicked: UiState.notifCenter = false }

    Rectangle {
        id: panel
        width: 392
        anchors { top: parent.top; bottom: parent.bottom; topMargin: Theme.barMarginTop + Theme.barHeight + 12; bottomMargin: 16 }
        x: UiState.notifCenter ? win.width - width - Theme.barMarginSide : win.width + 20
        Behavior on x { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }
        radius: Theme.radius + 4
        color: Theme.popupBg
        border.width: 1; border.color: Theme.border
        MouseArea { anchors.fill: parent }
        Shadowed { target: panel; z: -1 }
        focus: true
        Keys.onEscapePressed: UiState.notifCenter = false

        Row {
            id: head
            x: 16; y: 14; width: parent.width - 32; height: 30
            Text { text: "Notifications"; color: Theme.text; width: parent.width - 170
                font.family: Theme.font; font.pixelSize: Theme.fontLarge; font.bold: true
                anchors.verticalCenter: parent.verticalCenter }
            // Do not disturb
            Rectangle {
                width: 78; height: 26; radius: 13; anchors.verticalCenter: parent.verticalCenter
                color: NotificationService.dnd ? Theme.accent : Theme.surfaceAlt
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Row { anchors.centerIn: parent; spacing: 6
                    Glyph { text: NotificationService.dnd ? "" : ""; size: 11; color: NotificationService.dnd ? Theme.barCap : Theme.textDim }
                    Text { text: "DND"; font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1; font.bold: true
                        color: NotificationService.dnd ? Theme.barCap : Theme.textDim } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: NotificationService.toggleDnd() }
            }
            Item { width: 8; height: 1 }
            Rectangle {
                width: 78; height: 26; radius: 13; anchors.verticalCenter: parent.verticalCenter
                color: cc.containsMouse ? Theme.surfaceHigh : Theme.surfaceAlt
                Text { anchors.centerIn: parent; text: "Clear all"; color: Theme.textDim
                    font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1; font.bold: true }
                MouseArea { id: cc; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationService.clearAll() }
            }
        }

        ListView {
            anchors { top: head.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; margins: 16; topMargin: 12 }
            clip: true
            spacing: 10
            model: ScriptModel { values: NotificationService.history; objectProp: "key" }
            boundsBehavior: Flickable.StopAtBounds
            property int replyKey: -1
            delegate: NotificationItem {
                required property var modelData
                width: ListView.view.width
                entry: modelData
                onCloseRequested: NotificationService.remove(modelData.key)
                replying: ListView.view.replyKey === modelData.key
                onReplyRequested: ListView.view.replyKey = modelData.key
                onReplyClosed: ListView.view.replyKey = -1
            }
            Text {
                visible: NotificationService.count === 0
                anchors.centerIn: parent
                text: NotificationService.dnd ? "Do not disturb is on" : "No notifications"
                color: Theme.textMuted
                font.family: Theme.font; font.pixelSize: Theme.fontSize
            }
        }
    }
}
