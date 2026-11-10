import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../config"
import "../../components"

// One row of any kind: section header, app/window/file/action/web/clipboard entry, or the big calculator answer.
Item {
    id: root
    required property var item
    property bool selected: false
    signal activated()
    signal hoveredIn(real sceneX, real sceneY)

    readonly property bool header: item.kind === "header"
    readonly property bool calc: item.kind === "calc"
    height: item.h

    // ---- section header ----
    Text {
        visible: root.header
        x: 16; anchors.bottom: parent.bottom; anchors.bottomMargin: 4
        text: root.item.title
        color: Theme.textMuted
        font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1; font.weight: Font.Medium
    }

    // ---- icon ----
    Item {
        id: iconBox
        visible: !root.header
        x: 14; width: root.calc ? 36 : 28; height: width
        anchors.verticalCenter: parent.verticalCenter
        readonly property string path: root.item.icon ? Quickshell.iconPath(root.item.icon, true) : ""
        IconImage {
            anchors.fill: parent
            visible: iconBox.path !== ""
            source: iconBox.path
            asynchronous: true
        }
        Rectangle {  // no themed icon: glyph or monogram tile
            anchors.fill: parent
            visible: iconBox.path === ""
            radius: 8
            color: root.selected ? Theme.surfaceAlt : Theme.surfaceHigh
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            Text {  // emoji, drawn by the colour emoji font
                anchors.centerIn: parent
                visible: !!root.item.emoji
                text: root.item.emoji || ""
                font.family: "Noto Color Emoji"; font.pixelSize: 17
            }
            Glyph {
                anchors.centerIn: parent
                visible: !!root.item.glyph
                text: root.item.glyph || ""; size: root.calc ? 18 : 14
                color: root.item.danger ? Theme.bad : Theme.accent
            }
            Text {
                anchors.centerIn: parent
                visible: !root.item.glyph && !root.item.emoji && !root.header
                text: root.item.title ? root.item.title.charAt(0).toUpperCase() : ""
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.Medium
            }
        }
    }

    // ---- text ----
    Column {
        visible: !root.header
        anchors.verticalCenter: parent.verticalCenter
        x: 14 + iconBox.width + 12
        width: root.width - x - hint.width - 28
        spacing: root.calc ? 2 : 1
        Text {
            width: parent.width
            text: root.item.title
            elide: Text.ElideRight
            color: root.item.danger && root.item.armed ? Theme.bad : (root.selected || root.calc ? Theme.text : Theme.textDim)
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            font.family: Theme.font; font.weight: root.calc ? Font.DemiBold : Font.Medium
            font.pixelSize: root.calc ? 24 : Theme.fontSize + 2
        }
        Text {
            width: parent.width
            readonly property bool show: Boolean(root.item.subtitle) && Boolean(root.selected || root.calc || root.item.alwaysSub)
            visible: show
            text: root.item.subtitle || ""
            elide: Text.ElideMiddle
            color: Theme.textMuted
            font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1
        }
    }

    // ---- action hint, only on the focused row ----
    Text {
        id: hint
        visible: !root.header
        anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
        text: root.item.hint || ""
        opacity: root.selected ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
        color: Theme.textMuted
        font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.header
        hoverEnabled: true
        onPositionChanged: (m) => { const p = mapToItem(null, m.x, m.y); root.hoveredIn(p.x, p.y) }
        onClicked: root.activated()
    }
}
