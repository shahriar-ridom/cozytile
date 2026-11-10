import QtQuick
import "../../config"

Rectangle {
    property bool show: false
    property alias text: t.text
    visible: show
    z: 50
    y: -height - 6; x: -width / 2 + 3
    width: t.implicitWidth + 14; height: t.implicitHeight + 8; radius: Theme.radiusSmall
    color: Theme.tooltipBg
    Text { id: t; anchors.centerIn: parent; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1 }
}
