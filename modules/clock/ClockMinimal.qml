import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"

// One huge, light time with a small accent rule and the date underneath.
ColumnLayout {
    id: root
    property var t
    readonly property real k: t ? t.sizeK : 1
    spacing: 10 * k

    Item {
        Layout.alignment: t ? t.align : Qt.AlignHCenter
        implicitWidth: timeText.implicitWidth + (extra.visible ? extra.implicitWidth + 8 * root.k : 0)
        implicitHeight: timeText.implicitHeight
        Text {
            id: timeText
            text: t ? t.hh + ":" + t.mm : ""
            color: Theme.text
            font.family: DesktopClockService.family; font.weight: Font.Light
            font.pixelSize: 132 * root.k
            font.letterSpacing: -3 * root.k
        }
        // seconds / AM-PM, sitting on the time's baseline
        Text {
            id: extra
            visible: t && (t.showSeconds || t.ampm !== "")
            anchors.left: timeText.right; anchors.leftMargin: 8 * root.k
            anchors.baseline: timeText.baseline
            text: t ? (t.showSeconds ? ":" + t.ss : "") + (t.ampm ? (t.showSeconds ? " " : "") + t.ampm : "") : ""
            color: Theme.accent
            font.family: DesktopClockService.family; font.weight: Font.Medium
            font.pixelSize: 32 * root.k
        }
    }
    Rectangle {
        visible: t && t.showDate
        Layout.alignment: t ? t.align : Qt.AlignHCenter
        Layout.topMargin: 6 * root.k
        implicitWidth: 44 * root.k; implicitHeight: 3
        radius: 2; color: Theme.accent
    }
    Text {
        visible: t && t.showDate
        Layout.alignment: t ? t.align : Qt.AlignHCenter
        text: t ? t.weekday.toUpperCase() + "  ·  " + t.dayMonth.toUpperCase() : ""
        color: Theme.textDim
        font.family: DesktopClockService.family; font.weight: Font.DemiBold
        font.pixelSize: 17 * root.k
        font.letterSpacing: 4 * root.k
    }
}
