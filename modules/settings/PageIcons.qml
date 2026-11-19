import QtQuick
import Quickshell.Widgets
import "../../config"
import "../../services"
import "../../components"

// Icon packs: pick the system icon theme (apps, launcher, dock), install new packs, remove user-installed ones.
Column {
    id: page
    property var panel
    width: parent ? parent.width : 0
    Component.onCompleted: IconService.refresh()

    Section { text: "Icon pack" }
    SettingRow {
        title: "Applies everywhere"; desc: "GTK and Qt apps, the launcher and the dock. The shell restarts for a moment to load it; some apps need a restart too"
    }
    Flow {
        id: grid
        width: parent.width
        spacing: 10
        readonly property real cardW: (width - spacing) / 2
        Repeater {
            model: IconService.packs
            Rectangle {
                id: card
                required property var modelData
                readonly property bool active: modelData.id === IconService.current
                width: grid.cardW; height: 92
                radius: Theme.radius
                color: hover.containsMouse && !active ? Theme.surfaceHigh : Theme.surfaceAlt
                border.width: active ? 2 : 1
                border.color: active ? Theme.accent : Theme.slash
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Row {
                    x: 12; y: 12
                    spacing: 8
                    Repeater {
                        model: card.modelData.preview
                        IconImage { required property string modelData; source: "file://" + modelData; implicitSize: 32 }
                    }
                    Text {
                        visible: card.modelData.preview.length === 0
                        text: "No preview"; color: Theme.textMuted
                        font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1; height: 32; verticalAlignment: Text.AlignVCenter
                    }
                }
                Row {
                    x: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                    spacing: 8
                    Text { text: card.modelData.name; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true }
                    Text {
                        anchors.baseline: parent.children[0].baseline
                        text: card.active ? "In use" : card.modelData.user ? "Installed by you" : "System"
                        color: card.active ? Theme.accent : Theme.textMuted
                        font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1
                    }
                }
                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: card.active ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: if (!card.active) IconService.apply(card.modelData.id)
                }
                IconButton {
                    visible: card.modelData.user && !card.active && hover.containsMouse
                    anchors { right: parent.right; bottom: parent.bottom; margins: 6 }
                    glyph: ""; label: "Remove"; size: 28
                    onClicked: IconService.remove(card.modelData.id)
                }
            }
        }
    }

    Section { text: "Install" }
    SettingRow {
        title: "Add a pack"
        desc: "A .tar.gz, .tar.xz or .zip archive, an unpacked folder, or a download link. Packs go to ~/.local/share/icons"
    }
    Row {
        width: parent.width
        spacing: 8
        TextField {
            id: src
            width: parent.width - installBtn.width - parent.spacing
            placeholder: "~/Downloads/pack.tar.xz or https://…"
            onAccepted: IconService.install(text)
        }
        Chip {
            id: installBtn
            anchors.verticalCenter: parent.verticalCenter
            glyph: ""; label: IconService.busy ? "Working" : "Install"; primary: true
            onClicked: IconService.install(src.text)
        }
    }
    Text {
        visible: IconService.status !== ""
        width: parent.width; topPadding: 8
        wrapMode: Text.WordWrap
        text: IconService.status
        color: IconService.failed ? Theme.bad : Theme.textDim
        font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1
    }
    Connections {
        target: IconService
        function onBusyChanged() { if (!IconService.busy && !IconService.failed && IconService.status.startsWith("Installed")) src.clear(); }
    }
}
