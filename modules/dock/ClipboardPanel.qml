import QtQuick
import "../../config"
import "../../services"

// Clipboard history: click an entry to copy it again, pin text to keep it past a clear.
Column {
    id: root

    property var host
    readonly property var pinned: Settings.dockClipPinned.map(t => ({ id: "", text: t, image: false, kept: true }))
    readonly property var rows: pinned.concat(ClipboardService.entries.filter(e => !ClipboardService.isPinned(e.text)))
    readonly property int rowH: 34

    width: 360
    spacing: 8
    readonly property bool active: host ? host.open : false
    onActiveChanged: if (active) ClipboardService.refresh()
    Component.onCompleted: ClipboardService.refresh()

    Item {
        width: parent.width; height: 26
        Text {
            anchors.verticalCenter: parent.verticalCenter
            x: 4
            text: "Clipboard"
            color: Theme.text
            font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true
        }
        Rectangle {
            visible: ClipboardService.entries.length > 0
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: clearText.implicitWidth + 20; height: 24
            radius: Theme.radiusSmall + 2
            color: clearArea.containsMouse ? Theme.hover : "transparent"
            Text {
                id: clearText
                anchors.centerIn: parent
                text: "Clear"
                color: clearArea.containsMouse ? Theme.wsUrgent : Theme.textMuted
                font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1
            }
            MouseArea { id: clearArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ClipboardService.clear() }
        }
    }

    Text {
        visible: root.rows.length === 0
        width: parent.width; height: 70
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        text: ClipboardService.missing ? "Clipboard history needs cliphist and wl-clipboard.\nInstall both to use it." : "Nothing copied yet"
        color: Theme.textMuted
        font.family: Theme.font; font.pixelSize: Theme.fontSize
    }

    ListView {
        visible: root.rows.length > 0
        width: parent.width
        height: Math.min(8, root.rows.length) * root.rowH
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.rows
        delegate: Item {
            id: row
            required property var modelData
            width: ListView.view.width; height: root.rowH
            readonly property bool kept: ClipboardService.isPinned(modelData.text)
            Rectangle {
                anchors { fill: parent; topMargin: 1; bottomMargin: 1 }
                radius: Theme.radiusSmall + 2
                color: area.containsMouse ? Theme.hover : "transparent"
            }
            Rectangle {
                visible: row.kept
                x: 8; width: 5; height: 5; radius: 3
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.accent
            }
            Text {
                x: 22; width: parent.width - 22 - 60
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.text
                elide: Text.ElideRight
                color: row.modelData.image ? Theme.textMuted : Theme.text
                font.family: Theme.font; font.pixelSize: Theme.fontSize
                font.italic: row.modelData.image
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (row.modelData.kept || !row.modelData.id) ClipboardService.copyText(row.modelData.text); else ClipboardService.copy(row.modelData);
                    root.host.close();
                }
            }
            // images can't be pinned (only text is kept)
            Rectangle {
                visible: area.containsMouse && !row.modelData.image
                anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                width: pinText.implicitWidth + 16; height: 22
                radius: Theme.radiusSmall + 2
                color: pinArea.containsMouse ? Theme.press : Theme.hover
                Text {
                    id: pinText
                    anchors.centerIn: parent
                    text: row.kept ? "Unpin" : "Pin"
                    color: Theme.text
                    font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1
                }
                MouseArea { id: pinArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ClipboardService.togglePin(row.modelData.text) }
            }
        }
    }
}
