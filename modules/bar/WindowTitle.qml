import QtQuick
import Quickshell.Hyprland
import "../../config"

Text {
    id: root
    readonly property var tl: Hyprland.activeToplevel
    text: tl && tl.title ? tl.title : ""
    color: Theme.barText
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    font.bold: true
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    opacity: text.length ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
}
