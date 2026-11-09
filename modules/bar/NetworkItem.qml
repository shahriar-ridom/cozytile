import QtQuick
import Quickshell
import "../../config"
import "../../services"

StatItem {
    icon: NetworkService.icon()
    value: NetworkService.kind === "wifi" ? NetworkService.name : NetworkService.kind === "wired" ? "Wired" : "Offline"
    iconColor: NetworkService.online ? Theme.barTextDim : Theme.bad
    onClicked: m => Quickshell.execDetached(["sh", "-c", "command -v nm-connection-editor >/dev/null && exec nm-connection-editor || exec nmtui"])
}
