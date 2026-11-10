import QtQuick
import "../config"

// [-] value [+] for small integers / decimals. Emits stepped(value) clamped to [from, to].
Rectangle {
    id: root
    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 1
    property int decimals: 0
    property string suffix: ""
    signal stepped(real value)

    implicitWidth: 112; implicitHeight: 26
    radius: Theme.radiusSmall + 2
    color: Theme.surfaceAlt

    function bump(d) {
        const v = Math.max(from, Math.min(to, Math.round((value + d * step) / step) * step));
        if (v !== value) stepped(Number(v.toFixed(decimals)));
    }

    component Btn: Rectangle {
        id: b
        property string glyph
        property int dir
        width: 26; height: root.height - 4; radius: Theme.radiusSmall + 1
        anchors.verticalCenter: parent.verticalCenter
        color: ma.containsMouse ? Theme.hover : "transparent"
        opacity: (dir < 0 ? root.value > root.from : root.value < root.to) ? 1 : 0.35
        Text { anchors.centerIn: parent; text: b.glyph; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontSize + 2; font.bold: true }
        MouseArea {
            id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: root.bump(b.dir)
            onPressAndHold: hold.start()
            onReleased: hold.stop()
        }
        Timer { id: hold; interval: 70; repeat: true; onTriggered: root.bump(b.dir) }
    }

    Btn { x: 2; glyph: "−"; dir: -1 }
    Text {
        anchors.centerIn: parent
        text: Number(root.value).toFixed(root.decimals) + root.suffix
        color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontSmall + 2; font.bold: true
    }
    Btn { x: root.width - width - 2; glyph: "+"; dir: 1 }

    WheelHandler { onWheel: e => root.bump(e.angleDelta.y > 0 ? 1 : -1) }
}
