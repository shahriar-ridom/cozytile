import QtQuick
import "../../components"
import "../../config"

// Icon + value pair used by the right-hand stats.
Item {
    id: root
    property string icon: ""
    property string value: ""
    property color iconColor: Theme.barTextDim
    property color valueColor: Theme.barText
    signal clicked(var mouse)
    signal wheel(var wheel)

    // centre x of this item in the bar window (the popup is anchored to it)
    function centerX() { return root.mapToItem(null, root.width / 2, 0).x; }

    implicitWidth: row.implicitWidth + 12
    implicitHeight: Theme.barHeight

    HoverArea {
        anchors.fill: parent
        anchors.topMargin: 3; anchors.bottomMargin: 3
        radius: Theme.radiusSmall + 2
        acceptedButtons: Qt.LeftButton
        onClicked: m => root.clicked(m)
        onWheel: w => root.wheel(w)
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7
        Glyph { text: root.icon; color: root.iconColor; anchors.verticalCenter: parent.verticalCenter; Behavior on color { ColorAnimation { duration: Theme.animNormal } } }
        Text {
            text: root.value
            color: root.valueColor
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
