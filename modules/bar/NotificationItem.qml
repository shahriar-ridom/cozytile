import QtQuick
import "../../config"
import "../../services"

// Bell with unread-ish count. Click = centre, right click = do-not-disturb.
StatItem {
    icon: NotificationService.dnd ? "" : ""
    value: NotificationService.count > 0 ? NotificationService.count : ""
    iconColor: NotificationService.dnd ? Theme.warn : NotificationService.count > 0 ? Theme.accent : Theme.barTextDim
    implicitWidth: NotificationService.count > 0 ? super_w : 28
    readonly property int super_w: 46
    onClicked: m => m.button === Qt.RightButton ? NotificationService.toggleDnd() : UiState.toggle("notifCenter")
}
