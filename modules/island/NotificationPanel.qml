import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../config"
import "../../services"
import "../../components"

// Latest notifications inside the expanded island, with dismiss, actions and a link to the full centre.
Item {
    id: root
    property int maxListHeight: 200
    implicitHeight: col.implicitHeight
    implicitWidth: 428
    readonly property var rows: NotificationService.history
    property var replyKey: null            // card whose inline reply box is open

    function ago(t) {
        const s = Math.floor((Date.now() - t.getTime()) / 1000);
        if (s < 60) return "now";
        if (s < 3600) return Math.floor(s / 60) + "m";
        if (s < 86400) return Math.floor(s / 3600) + "h";
        return Qt.formatDate(t, "d MMM");
    }

    Column {
        id: col
        width: parent.width
        spacing: 8

        Item {
            width: parent.width; height: 24
            Row {
                spacing: 8; anchors.verticalCenter: parent.verticalCenter
                Text { text: "Notifications"; color: Theme.text; anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true }
                Rectangle {
                    visible: NotificationService.count > 0
                    width: cnt.implicitWidth + 12; height: 18; radius: 9; color: Theme.accent
                    anchors.verticalCenter: parent.verticalCenter
                    Text { id: cnt; anchors.centerIn: parent; text: NotificationService.count; color: Theme.barCap
                        font.family: Theme.font; font.pixelSize: Theme.fontSmall; font.bold: true }
                }
            }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 4
                IconButton { glyph: NotificationService.dnd ? "" : ""; size: 24; glyphSize: 11; active: NotificationService.dnd
                    onClicked: NotificationService.toggleDnd() }
                IconButton { label: "Mark all read"; glyph: "\uf00c"; size: 24; visible: NotificationService.count > 0
                    onClicked: { root.replyKey = null; NotificationService.markAllRead(""); } }
            }
        }

        ListView {
            id: list
            width: parent.width
            height: Math.min(contentHeight, root.maxListHeight)
            visible: root.rows.length > 0
            clip: true
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds
            model: ScriptModel { values: root.rows; objectProp: "key" }
            delegate: Rectangle {
                id: card
                required property var modelData
                required property int index
                onReplyingChanged: if (replying) Qt.callLater(() => list.positionViewAtIndex(index, ListView.Contain))
                readonly property bool live: modelData.n !== null
                readonly property bool replying: live && root.replyKey === modelData.key
                readonly property var extra: modelData.actions.filter(a => a.identifier !== "default" && a.identifier !== modelData.markRead).slice(0, 2)
                width: list.width
                height: rowc.implicitHeight + 16
                radius: Theme.radius
                color: Theme.surfaceAlt
                border.width: modelData.urgency === 2 ? 1 : 0
                border.color: Theme.bad

                Row {
                    id: rowc
                    x: 10; y: 8; width: parent.width - 20; spacing: 10
                    Item {
                        id: ib
                        width: 30; height: 30
                        readonly property string name: card.modelData.appIcon || (card.modelData.image.startsWith("image://icon/") ? card.modelData.image.slice(13) : "")
                        readonly property string path: name ? Quickshell.iconPath(name, true) : ""
                        Rectangle { anchors.fill: parent; radius: 8; color: Theme.surfaceHigh }
                        IconImage { anchors.fill: parent; anchors.margins: 2; visible: ib.path !== ""; source: ib.path; asynchronous: true }
                        Glyph { anchors.centerIn: parent; visible: ib.path === ""; text: ""; size: 12; color: Theme.textDim }
                    }
                    Column {
                        width: parent.width - 30 - 10 - 26
                        spacing: 2
                        Row {
                            width: parent.width
                            Text { width: parent.width - when.implicitWidth - 6; text: card.modelData.summary || card.modelData.appName
                                elide: Text.ElideRight; color: Theme.text
                                font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                            Text { id: when; text: root.ago(card.modelData.time); color: Theme.textMuted
                                font.family: Theme.font; font.pixelSize: Theme.fontSmall - 1 }
                        }
                        Text { width: parent.width; visible: text !== ""; text: card.modelData.body
                            maximumLineCount: 2; wrapMode: Text.Wrap; elide: Text.ElideRight; color: Theme.textDim
                            font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1 }
                        Rectangle {
                            visible: card.modelData.progress >= 0
                            width: parent.width; height: 4; radius: 2; color: Theme.osdTrack
                            Rectangle { height: parent.height; radius: 2; color: Theme.accent; width: parent.width * Math.max(0, card.modelData.progress)
                                Behavior on width { NumberAnimation { duration: Theme.animNormal } } }
                        }
                        Flow {
                            width: parent.width
                            topPadding: 4
                            spacing: 6
                            visible: card.live && !card.replying && (card.modelData.canReply || card.modelData.markRead !== "" || card.extra.length > 0)
                            Chip {
                                visible: card.modelData.canReply
                                glyph: "\uf112"; label: "Reply"; primary: true
                                onClicked: root.replyKey = card.modelData.key
                            }
                            Repeater {
                                model: card.extra
                                delegate: Chip {
                                    required property var modelData
                                    label: modelData.text
                                    onClicked: NotificationService.invoke(card.modelData.key, modelData.identifier)
                                }
                            }
                            Chip {
                                visible: card.modelData.markRead !== ""
                                glyph: "\uf00c"; label: "Mark as read"
                                onClicked: NotificationService.markRead(card.modelData.key)
                            }
                        }
                        Item { width: 1; height: 4; visible: card.replying }
                        ReplyField {
                            id: replyBox
                            width: parent.width
                            visible: card.replying
                            placeholder: card.modelData.replyPlaceholder || ("Reply to " + (card.modelData.summary || card.modelData.appName) + "…")
                            onVisibleChanged: { if (visible) Qt.callLater(focusInput); else text = ""; }
                            // the list model is rebuilt on every history change: refocus a recreated box
                            Component.onCompleted: if (visible) Qt.callLater(focusInput)
                            onCancelled: root.replyKey = null
                            // replying removes this card: finish UI work first, send last
                            onSent: t => {
                                const key = card.modelData.key;
                                root.replyKey = null;
                                const ok = NotificationService.canReply(key);
                                ActivityService.toast("reply", ok ? "\uf1d8" : "\uf071", ok ? "Reply sent" : "Reply failed · notification closed", ok ? "good" : "bad");
                                NotificationService.reply(key, t);
                            }
                        }
                    }
                    IconButton { glyph: ""; size: 22; glyphSize: 10; onClicked: NotificationService.remove(card.modelData.key) }
                }
            }
        }

        Text {
            visible: root.rows.length === 0
            width: parent.width; horizontalAlignment: Text.AlignHCenter
            text: NotificationService.dnd ? "Do not disturb is on" : "You're all caught up"
            color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.fontSize
            topPadding: 6; bottomPadding: 6
        }
    }
}
