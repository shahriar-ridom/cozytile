import QtQuick
import "../config"

// Subtle hover/press highlight with click handling. Place over a row of content.
Item {
    id: root
    property alias hovered: mouse.containsMouse
    property alias pressed: mouse.pressed
    property int radius: Theme.radiusSmall
    property int inset: 0
    property bool highlight: true
    signal clicked(var mouse)
    signal wheel(var wheel)
    property alias acceptedButtons: mouse.acceptedButtons
    property alias cursorShape: mouse.cursorShape

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.inset
        radius: root.radius
        color: mouse.pressed ? Theme.press : (mouse.containsMouse ? Theme.hover : "transparent")
        visible: root.highlight
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => root.clicked(m)
        onWheel: w => root.wheel(w)
    }
}
