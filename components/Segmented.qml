import QtQuick
import "../config"

// Row of exclusive options. model: [{ label, value }].
Rectangle {
    id: root
    property var model: []
    property var current
    signal picked(var value)

    implicitHeight: 26
    implicitWidth: row.implicitWidth + 4
    radius: Theme.radiusSmall + 2
    color: Theme.surfaceAlt

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2
        Repeater {
            model: root.model
            delegate: Rectangle {
                required property var modelData
                readonly property bool on: root.current === modelData.value
                width: lbl.implicitWidth + 20; height: root.height - 4
                radius: Theme.radiusSmall + 1
                color: on ? Theme.surfaceHigh : (m.containsMouse ? Theme.hover : "transparent")
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Text {
                    id: lbl; anchors.centerIn: parent; text: modelData.label
                    color: parent.on ? Theme.text : Theme.textDim
                    font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1; font.bold: parent.on
                }
                MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(modelData.value) }
            }
        }
    }
}
