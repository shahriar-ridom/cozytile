import QtQuick
import Quickshell
import "../../config"
import "../../services"
import "../../components"

// Screenshot: pick what to capture. The card closes first; scripts/screenshot.sh saves, copies and notifies.
Column {
    id: root

    property var host
    readonly property var modes: [
        { id: "region", label: "Region", glyph: "󰐻" },
        { id: "window", label: "Window", glyph: "󰕚" },
        { id: "screen", label: "Screen", glyph: "󰍹" }
    ]

    spacing: 10
    Text {
        x: 4
        text: "Screenshot"
        color: Theme.text
        font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true
    }
    Row {
        spacing: 8
        Repeater {
            model: root.modes
            Rectangle {
                id: tile
                required property var modelData
                width: 84; height: 74
                radius: Theme.radius
                color: area.containsMouse ? Theme.press : Theme.hover
                scale: area.pressed ? 0.96 : 1
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                Glyph {
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 12 }
                    text: tile.modelData.glyph
                    size: 28
                    color: area.containsMouse ? Theme.accent : Theme.text
                }
                Text {
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 10 }
                    text: tile.modelData.label
                    color: Theme.text
                    font.family: Theme.font; font.pixelSize: Theme.fontSize
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.host.close();
                        Quickshell.execDetached([Quickshell.shellPath("scripts/screenshot.sh"), tile.modelData.id]);
                    }
                }
            }
        }
    }
}
