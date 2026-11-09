import QtQuick
import "../config"

// Horizontal slider: click or drag to set value (0..1).
Item {
    id: root
    property real value: 0
    property color fillColor: Theme.accent
    property color trackColor: Theme.osdTrack
    signal moved(real v)
    implicitHeight: 18
    implicitWidth: 120

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width; height: 5; radius: 3
        color: root.trackColor
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.value)); height: parent.height; radius: 3
            color: root.fillColor
            Behavior on width { enabled: !area.pressed; NumberAnimation { duration: Theme.animFast } }
        }
    }
    Rectangle {  // handle, visible on hover/drag
        width: 12; height: 12; radius: 6
        anchors.verticalCenter: parent.verticalCenter
        x: (root.width - width) * Math.max(0, Math.min(1, root.value))
        color: root.fillColor
        opacity: area.containsMouse || area.pressed ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        function set(x) { root.moved(Math.max(0, Math.min(1, x / width))); }
        onPressed: m => set(m.x)
        onPositionChanged: m => { if (pressed) set(m.x); }
    }
}
