import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"

// Hours over minutes in heavy type (minutes in the accent colour), with the date in a pill.
ColumnLayout {
    id: root
    property var t
    readonly property real k: t ? t.sizeK : 1
    readonly property int al: t ? t.align : Qt.AlignHCenter
    spacing: 14 * k

    ColumnLayout {
        Layout.alignment: root.al
        spacing: -34 * root.k
        Text {
            Layout.alignment: root.al
            text: t ? t.hh : ""
            color: Theme.text
            font.family: DesktopClockService.family; font.weight: Font.Bold
            font.pixelSize: 150 * root.k
        }
        Text {
            Layout.alignment: root.al
            text: t ? t.mm : ""
            color: Theme.accent
            font.family: DesktopClockService.family; font.weight: Font.Bold
            font.pixelSize: 150 * root.k
        }
    }
    Rectangle {
        visible: t && (t.showDate || t.showSeconds || t.ampm !== "")
        Layout.alignment: root.al
        implicitWidth: pill.implicitWidth + 28 * root.k
        implicitHeight: pill.implicitHeight + 14 * root.k
        radius: height / 2
        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.62)
        border.width: 1; border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.14)
        Text {
            id: pill
            anchors.centerIn: parent
            text: {
                if (!t) return "";
                const parts = [];
                if (t.showDate) parts.push(Qt.formatDateTime(t.now, "ddd d MMM"));
                const tm = (t.showSeconds ? ":" + t.ss : "") + (t.ampm ? (t.showSeconds ? " " : "") + t.ampm : "");
                if (tm) parts.push(tm.trim());
                return parts.join("  ·  ");
            }
            color: Theme.text
            font.family: DesktopClockService.family; font.weight: Font.DemiBold
            font.pixelSize: 15 * root.k
            font.letterSpacing: 1 * root.k
        }
    }
}
