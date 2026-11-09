import QtQuick
import "../config"

// Round glyph button. `filled` = accent background (primary action).
Rectangle {
    id: root
    property string glyph: ""
    property int size: 32
    property int glyphSize: 13
    property bool filled: false
    property bool active: false
    property string label: ""
    signal clicked(var mouse)

    implicitWidth: label ? Math.max(size, row.implicitWidth + 20) : size
    implicitHeight: size
    radius: size / 2
    color: filled ? Theme.accent : active ? Theme.surfaceHigh : (area.containsMouse ? Theme.hover : "transparent")
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    scale: area.pressed ? 0.94 : 1
    Behavior on scale { NumberAnimation { duration: 80 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7
        Glyph { text: root.glyph; size: root.glyphSize; color: root.filled ? Theme.barCap : root.active ? Theme.accent : Theme.text
            anchors.verticalCenter: parent.verticalCenter }
        Text {
            visible: root.label !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.label; color: root.filled ? Theme.barCap : Theme.textDim
            font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1; font.bold: true
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => root.clicked(m)
    }
}
