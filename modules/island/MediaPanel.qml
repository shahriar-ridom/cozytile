import QtQuick
import Quickshell
import "../../config"
import "../../services"
import "../../components"

// Expanded now-playing card: artwork, seekable progress, transport, volume.
Item {
    id: root
    readonly property var pl: MediaService.player
    implicitHeight: col.implicitHeight
    implicitWidth: 428

    function fmt(sec) {
        sec = Math.max(0, Math.floor(sec || 0));
        return Math.floor(sec / 60) + ":" + String(sec % 60).padStart(2, "0");
    }
    // MPRIS position is not pushed; poll once a second only while visible and playing.
    Timer {
        interval: 1000; repeat: true; triggeredOnStart: true
        running: root.visible && MediaService.playing && root.pl !== null
        onTriggered: root.pl.positionChanged()
    }

    Column {
        id: col
        width: parent.width
        spacing: 10

        Row {
            spacing: 14
            width: parent.width
            Rectangle {
                width: 76; height: 76; radius: 14
                color: Theme.surfaceHigh
                clip: true
                Image {
                    id: art
                    anchors.fill: parent
                    source: MediaService.art
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 160
                    visible: status === Image.Ready
                }
                Glyph { anchors.centerIn: parent; text: ""; size: 24; color: Theme.textMuted; visible: art.status !== Image.Ready }
            }
            Column {
                width: parent.width - 76 - 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Text { width: parent.width; text: MediaService.title; elide: Text.ElideRight; color: Theme.text
                    font.family: Theme.font; font.pixelSize: Theme.fontLarge; font.bold: true }
                Text { width: parent.width; text: MediaService.artist; elide: Text.ElideRight; color: Theme.textDim
                    visible: text !== ""; font.family: Theme.font; font.pixelSize: Theme.fontSize }
                Text { width: parent.width; text: MediaService.album; elide: Text.ElideRight; color: Theme.textMuted
                    visible: text !== ""; font.family: Theme.font; font.pixelSize: Theme.fontSmall }
                Text { width: parent.width; text: root.pl ? root.pl.identity : ""; elide: Text.ElideRight; color: Theme.textMuted
                    visible: text !== ""; font.family: Theme.font; font.pixelSize: Theme.fontSmall - 1 }
            }
        }

        // progress (seekable when the player allows it)
        Column {
            width: parent.width
            spacing: 2
            visible: root.pl && root.pl.lengthSupported && root.pl.length > 0
            SliderBar {
                width: parent.width
                value: root.pl && root.pl.length > 0 ? root.pl.position / root.pl.length : 0
                enabled: root.pl && root.pl.canSeek
                onMoved: v => { if (root.pl && root.pl.canSeek) root.pl.position = v * root.pl.length; }
            }
            Item {
                width: parent.width; height: 12
                Text { text: root.fmt(root.pl ? root.pl.position : 0); color: Theme.textMuted
                    font.family: Theme.font; font.pixelSize: Theme.fontSmall - 1 }
                Text { anchors.right: parent.right; text: root.fmt(root.pl ? root.pl.length : 0); color: Theme.textMuted
                    font.family: Theme.font; font.pixelSize: Theme.fontSmall - 1 }
            }
        }

        // transport
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            IconButton { glyph: ""; size: 30; glyphSize: 12; visible: root.pl && root.pl.shuffleSupported
                active: root.pl && root.pl.shuffle; onClicked: root.pl.shuffle = !root.pl.shuffle }
            IconButton { glyph: ""; size: 34; opacity: root.pl && root.pl.canGoPrevious ? 1 : 0.4; onClicked: MediaService.previous() }
            IconButton { glyph: MediaService.playing ? "" : ""; size: 42; glyphSize: 15; filled: true; onClicked: MediaService.toggle() }
            IconButton { glyph: ""; size: 34; opacity: root.pl && root.pl.canGoNext ? 1 : 0.4; onClicked: MediaService.next() }
            IconButton { glyph: ""; size: 30; glyphSize: 12; visible: root.pl && root.pl.loopSupported
                active: root.pl && root.pl.loopState !== 0
                onClicked: root.pl.loopState = (root.pl.loopState === 0 ? 2 : 0) }   // none <-> playlist
        }

        // output volume
        Row {
            width: parent.width; spacing: 10
            IconButton { glyph: AudioService.icon(); size: 26; glyphSize: 12; onClicked: AudioService.toggleMute() }
            SliderBar {
                width: parent.width - 26 - 10 - 38 - 20
                anchors.verticalCenter: parent.verticalCenter
                value: AudioService.muted ? 0 : AudioService.volume
                onMoved: v => AudioService.setVolume(v)
            }
            Text { width: 38; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignRight
                text: Math.round(AudioService.volume * 100) + "%"; color: Theme.textDim
                font.family: Theme.font; font.pixelSize: Theme.fontSmall }
        }
    }
}
