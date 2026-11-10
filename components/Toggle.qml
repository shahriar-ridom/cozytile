import QtQuick
import "../config"

// Pill switch.
Rectangle {
    id: root
    property bool checked: false
    signal toggled(bool value)

    implicitWidth: 36; implicitHeight: 20; radius: height / 2
    color: checked ? Theme.accent : Theme.surfaceHigh
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    Rectangle {
        width: 14; height: 14; radius: 7
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 3 : 3
        color: root.checked ? Theme.barCap : Theme.textDim
        Behavior on x { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
