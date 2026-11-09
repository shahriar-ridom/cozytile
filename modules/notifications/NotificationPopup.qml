import QtQuick
import Quickshell
import Quickshell.Wayland
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
    mask: Region { item: stack }

    Column {
        id: stack
        x: 0; y: 0
        width: 360
        spacing: 10
        Repeater {
            model: win.items
            delegate: NotificationItem {
                id: card
                required property var modelData
                entry: modelData
                popup: true
                width: 360
                onCloseRequested: NotificationService.dismissPopup(modelData.key)

                // auto-expire popup (not critical); hover pauses
                Timer {
                    interval: card.entry.urgency === 2 ? 0 : 6000
                    running: interval > 0 && !hover.hovered
                    onTriggered: NotificationService.dismissPopup(card.entry.key)
                }
                HoverHandler { id: hover }
                TapHandler { onTapped: NotificationService.dismissPopup(card.entry.key) }

                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                Shadowed { target: card; z: -1 }
            }
        }
    }
}
