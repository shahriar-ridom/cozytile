import QtQuick
import "../../components"
import QtQuick.Layouts
import "../../config"
import "../../services"

// Round glass face with tick marks, hour/minute hands and an optional accent second hand.
ColumnLayout {
    id: root
    property var t
    readonly property real k: t ? t.sizeK : 1
    readonly property real size: 230 * k
    readonly property real r: size / 2
    readonly property date now: t ? t.now : new Date()
    readonly property real sec: t && t.showSeconds ? now.getSeconds() : 0
    readonly property real min: now.getMinutes() + sec / 60
    readonly property real hr: (now.getHours() % 12) + min / 60
    spacing: 16 * k

    Rectangle {
        id: face
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: root.size; implicitHeight: root.size
        radius: width / 2
        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.55)
        border.width: 1; border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.16)

        // minute ticks (every 5th is a heavier hour mark)
        Repeater {
            model: 60
            delegate: Item {
                required property int index
                readonly property bool major: index % 5 === 0
                anchors.centerIn: parent
                width: 0; height: 0
                rotation: index * 6
                Rectangle {
                    x: -width / 2
                    y: -root.r + 9 * root.k
                    width: (major ? 3 : 1.5) * root.k
                    height: (major ? 11 : 5) * root.k
                    radius: width / 2
                    color: major ? Theme.text : Theme.textMuted
                    opacity: major ? 0.9 : 0.6
                }
            }
        }

        // hour hand
        Item {
            anchors.centerIn: parent; width: 0; height: 0
            rotation: root.hr * 30
            Rectangle { x: -width / 2; y: -root.r * 0.5; width: 6 * root.k; height: root.r * 0.5 + 8 * root.k
                radius: width / 2; color: Theme.text }
        }
        // minute hand
        Item {
            anchors.centerIn: parent; width: 0; height: 0
            rotation: root.min * 6
            Rectangle { x: -width / 2; y: -root.r * 0.76; width: 4 * root.k; height: root.r * 0.76 + 10 * root.k
                radius: width / 2; color: Theme.text }
        }
        // second hand
        Item {
            visible: t && t.showSeconds
            anchors.centerIn: parent; width: 0; height: 0
            rotation: root.sec * 6
            Rectangle { x: -width / 2; y: -root.r * 0.84; width: 2 * root.k; height: root.r * 0.84 + 18 * root.k
                radius: width / 2; color: Theme.accent }
        }
        // hub
        Rectangle { anchors.centerIn: parent; width: 12 * root.k; height: width; radius: width / 2; color: Theme.accent }
        Rectangle { anchors.centerIn: parent; width: 4 * root.k; height: width; radius: width / 2; color: Theme.surface }
    }
    Text {
        visible: t && t.showDate
        Layout.alignment: Qt.AlignHCenter
        text: t ? t.weekday.toUpperCase() + "  ·  " + t.dayMonth.toUpperCase() : ""
        color: Theme.textDim
        font.family: DesktopClockService.family; font.weight: Font.DemiBold
        font.pixelSize: 14 * root.k
        font.letterSpacing: 3 * root.k
    }
}
