import QtQuick
import "../../config"
import "../../services"
import "../../components"

// Timer controls in the expanded island: pick a duration and start, or watch/pause/extend/cancel.
Item {
    id: root
    implicitWidth: 428
    implicitHeight: TimerService.active ? runCol.implicitHeight : idleRow.implicitHeight
    property int pending: Settings.timerLast > 0 ? Settings.timerLast : 300

    // idle: presets + stepper + start
    Row {
        id: idleRow
        visible: !TimerService.active
        width: parent.width
        spacing: 6
        Glyph { text: ""; color: Theme.textDim; size: 13; anchors.verticalCenter: parent.verticalCenter; width: 20 }
        Repeater {
            model: [{ l: "1m", s: 60 }, { l: "5m", s: 300 }, { l: "10m", s: 600 }, { l: "25m", s: 1500 }]
            delegate: IconButton {
                required property var modelData
                label: modelData.l; size: 28; active: root.pending === modelData.s
                onClicked: root.pending = modelData.s
            }
        }
        Item { width: 4; height: 1 }
        IconButton { glyph: ""; size: 26; glyphSize: 10; onClicked: root.pending = Math.max(60, root.pending - 60) }
        Text { width: 56; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter
            text: TimerService.format(root.pending); color: Theme.text
            font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true }
        IconButton { glyph: ""; size: 26; glyphSize: 10; onClicked: root.pending += 60 }
        IconButton { glyph: ""; size: 30; glyphSize: 11; filled: true; onClicked: TimerService.start(root.pending) }
    }

    // running / paused
    Column {
        id: runCol
        visible: TimerService.active
        width: parent.width
        spacing: 8
        Item {
            width: parent.width; height: 34
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text { text: TimerService.format(TimerService.remaining); color: TimerService.paused ? Theme.textDim : Theme.text
                    font.family: Theme.font; font.pixelSize: Theme.fontTitle; font.bold: true }
                Text { text: (TimerService.label || "Timer") + (TimerService.paused ? " · paused" : ""); color: Theme.textMuted
                    font.family: Theme.font; font.pixelSize: Theme.fontSmall }
            }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 6
                IconButton { label: "+1m"; size: 30; onClicked: TimerService.add(60) }
                IconButton { glyph: TimerService.paused ? "" : ""; size: 30; glyphSize: 11; filled: true; onClicked: TimerService.toggle() }
                IconButton { glyph: ""; size: 30; glyphSize: 11; onClicked: TimerService.stop() }
            }
        }
        Rectangle {
            width: parent.width; height: 5; radius: 3; color: Theme.osdTrack
            Rectangle { width: parent.width * TimerService.progress; height: parent.height; radius: 3
                color: TimerService.paused ? Theme.textMuted : Theme.accent
                Behavior on width { NumberAnimation { duration: 400 } } }
        }
    }
}
