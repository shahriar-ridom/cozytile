import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../config"
import "../../services"
import "../../components"

// Toast stack under the bar, top right. Only the stack area takes input.
PanelWindow {
    id: win
    screen: UiState.focusedScreen
    readonly property var items: NotificationService.popups.slice(0, 4)
    visible: (Settings.toasts || !UiState.islandActive) && items.length > 0
    color: "transparent"
    anchors { top: true; right: true }
    margins { top: Theme.barMarginTop + Theme.barHeight + 12; right: Theme.barMarginSide }
    implicitWidth: 360 + 24
    implicitHeight: stack.height + 24
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "cozytile-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    // toasts never take the keyboard, except while a reply is being typed
    WlrLayershell.keyboardFocus: replyKey >= 0 ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: stack }

    property int replyKey: -1
    onItemsChanged: if (replyKey >= 0 && !items.some(e => e.key === replyKey)) replyKey = -1
    // armed after the keyboard-focus switch lands, or Hyprland clears the grab immediately
    property bool replyGrab: false
    onReplyKeyChanged: { replyGrab = false; if (replyKey >= 0) grabArm.restart(); }
    Timer { id: grabArm; interval: 150; onTriggered: win.replyGrab = win.replyKey >= 0 }
    HyprlandFocusGrab { windows: [win]; active: win.replyGrab; onCleared: win.replyKey = -1 }

    Column {
        id: stack
        x: 0; y: 0
        width: 360
        spacing: 10
        Repeater {
            // keyed: a card survives unrelated history changes (keeps its timer and a half-typed reply)
            model: ScriptModel { values: win.items; objectProp: "key" }
            delegate: NotificationItem {
                id: card
                required property var modelData
                entry: modelData
                popup: true
                width: 360
                onCloseRequested: NotificationService.dismissPopup(modelData.key)
                replying: win.replyKey === modelData.key
                onReplyRequested: win.replyKey = modelData.key
                onReplyClosed: win.replyKey = -1
                onClicked: if (!replying) NotificationService.dismissPopup(entry.key)

                // auto-expire popup (not critical); hover pauses
                Timer {
                    interval: card.entry.urgency === 2 ? 0 : 6000
                    running: interval > 0 && !hover.hovered && !card.replying
                    onTriggered: NotificationService.dismissPopup(card.entry.key)
                }
                HoverHandler { id: hover }

                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                Shadowed { target: card; z: -1 }
            }
        }
    }
}
