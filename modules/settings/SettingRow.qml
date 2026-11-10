import QtQuick
import "../../config"

// Title + optional description on the left, control on the right.
Item {
    id: row
    property string title: ""
    property string desc: ""
    property bool modified: false      // small dot: value overrides the config default
    signal reset()
    default property alias control: slot.data
    width: parent ? parent.width : 0
    height: Math.max(48, col.implicitHeight + 16)
    Column {
        id: col
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - slot.width - 20
        spacing: 2
        Row {
            spacing: 6
            Text { text: row.title; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true }
            Rectangle {
                visible: row.modified
                anchors.verticalCenter: parent.verticalCenter
                width: 6; height: 6; radius: 3; color: Theme.accent
                MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                    onClicked: row.reset()
                    ToolTipLite { show: parent.containsMouse; text: "Changed here · click to reset" } }
            }
        }
        Text { visible: row.desc !== ""; width: parent.width; wrapMode: Text.WordWrap; text: row.desc
            color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1 }
    }
    Item { id: slot; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width; height: childrenRect.height }
}
