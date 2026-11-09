import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../config"

Item {
    id: root
    required property var entry
    property bool selected: false
    signal activated()
    signal hoveredIn()

    height: 44
    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: root.selected ? Theme.surfaceHigh : (mouse.containsMouse ? Theme.hover : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Rectangle {  // accent marker for the selected row
            width: 3; height: root.selected ? 18 : 0; radius: 2
            anchors.verticalCenter: parent.verticalCenter
            x: 4
            color: Theme.accent
            Behavior on height { NumberAnimation { duration: Theme.animFast } }
        }
    }
    Row {
        anchors.verticalCenter: parent.verticalCenter
        x: 16; spacing: 12
        Item {
            width: 28; height: 28
            anchors.verticalCenter: parent.verticalCenter
            readonly property string path: root.entry.icon ? Quickshell.iconPath(root.entry.icon, true) : ""
            IconImage {
                anchors.fill: parent
                visible: parent.path !== ""
                source: parent.path
                asynchronous: true
            }
            Rectangle {  // themed icon missing: draw a neutral monogram tile
                anchors.fill: parent
                visible: parent.path === ""
                radius: 7
                color: Theme.surfaceHigh
                Text { anchors.centerIn: parent; text: root.entry.name.charAt(0).toUpperCase()
                    color: Theme.textDim; font.family: Theme.font; font.pixelSize: 14; font.bold: true }
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                text: root.entry.name
                color: Theme.text
                font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true
            }
            Text {
                visible: text.length > 0
                text: root.entry.comment || root.entry.genericName || ""
                color: Theme.textDim
                font.family: Theme.font; font.pixelSize: Theme.fontSmall
                elide: Text.ElideRight
                width: root.width - 90
            }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onEntered: root.hoveredIn()
        onClicked: root.activated()
    }
}
