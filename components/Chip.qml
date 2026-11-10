import QtQuick
import "../config"

// Small pill button with optional glyph: notification actions (reply, mark read, app actions).
Rectangle {
    id: root
    property string glyph: ""
    property string label: ""
    property bool primary: false
    signal clicked()

    implicitHeight: 26
    implicitWidth: row.implicitWidth + 20
    radius: height / 2
    color: area.containsMouse || primary ? Theme.accent : Theme.surfaceHigh
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    scale: area.pressed ? 0.95 : 1
    Behavior on scale { NumberAnimation { duration: 80 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Glyph { visible: root.glyph !== ""; text: root.glyph; size: 10; anchors.verticalCenter: parent.verticalCenter
            color: area.containsMouse || root.primary ? Theme.barCap : Theme.text }
        Text { text: root.label; anchors.verticalCenter: parent.verticalCenter
            color: area.containsMouse || root.primary ? Theme.barCap : Theme.text
            font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1; font.bold: true }
    }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
