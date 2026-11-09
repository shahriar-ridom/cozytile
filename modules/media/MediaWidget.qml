import QtQuick
import "../../config"
import "../../components"
import "../../services"

// Compact now-playing item. Occupies no space unless a player has a track.
Item {
    id: root
    property int maxTextWidth: 190
    visible: MediaService.active
    implicitWidth: visible ? row.implicitWidth + 14 : 0
    implicitHeight: Theme.barHeight
    clip: true

    HoverArea {
        anchors.fill: parent; anchors.topMargin: 3; anchors.bottomMargin: 3
        radius: Theme.radiusSmall + 2
        onClicked: m => m.button === Qt.MiddleButton ? MediaService.next() : m.button === Qt.RightButton ? MediaService.previous() : MediaService.toggle()
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7
        Glyph {
            text: MediaService.playing ? "" : ""
            size: 10
            color: MediaService.playing ? Theme.accent : Theme.barTextDim
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.maxTextWidth)
            text: MediaService.artist ? MediaService.title + " — " + MediaService.artist : MediaService.title
            elide: Text.ElideRight
            color: Theme.barText
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            font.bold: true
        }
    }
}
