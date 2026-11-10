import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../config"
import "../../components"
import "../../services"

// One notification card (used by both the popup stack and the centre).
Rectangle {
    id: root
    required property var entry
    property bool popup: false
    property bool replying: false          // owner keeps this (one open reply box per window)
    signal closeRequested()
    signal clicked()                       // click on the card body (not a button)
    signal replyRequested()
    signal replyClosed()

    readonly property bool live: entry.n !== null
    readonly property var extra: entry.actions.filter(a => a.identifier !== "default" && a.identifier !== entry.markRead)

    readonly property bool critical: entry.urgency === 2   // NotificationUrgency.Critical
    implicitHeight: col0.implicitHeight + 24
    radius: Theme.radius
    color: Theme.notifBg
    border.width: 1
    border.color: critical ? Theme.bad : Theme.notifBorder

    function ago(t) {
        const s = Math.floor((Date.now() - t.getTime()) / 1000);
        if (s < 60) return "now";
        if (s < 3600) return Math.floor(s / 60) + "m";
        if (s < 86400) return Math.floor(s / 3600) + "h";
        return Qt.formatDate(t, "d MMM");
    }
    // re-evaluate relative time each minute without a per-item timer storm
    property int tick: 0
    Timer { interval: 60000; running: !root.popup; repeat: true; onTriggered: root.tick++ }

    // under every button: plain clicks on the card
    MouseArea { anchors.fill: parent; onClicked: root.clicked() }

    Row {
        id: col0
        x: 12; y: 12; spacing: 12
        width: parent.width - 24
        Item {
            id: iconBox
            width: 36; height: 36
            readonly property string iconName: root.entry.appIcon || (root.entry.image.startsWith("image://icon/") ? root.entry.image.slice(13) : "")
            readonly property string iconPath: iconName ? Quickshell.iconPath(iconName, true) : ""
            Rectangle { anchors.fill: parent; radius: 9; color: Theme.surfaceHigh; visible: img.status !== Image.Ready && iconBox.iconPath === "" }
            Image {
                id: img
                anchors.fill: parent
                // image://icon/<name> is just the app icon by name: handled below so missing themes don't show a checkerboard
                source: root.entry.image.startsWith("image://icon/") ? "" : root.entry.image
                fillMode: Image.PreserveAspectCrop
                visible: source !== "" && status === Image.Ready
                asynchronous: true
            }
            IconImage {
                anchors.fill: parent
                visible: img.status !== Image.Ready && iconBox.iconPath !== ""
                source: iconBox.iconPath
                asynchronous: true
            }
            Glyph { anchors.centerIn: parent; text: ""; color: Theme.textDim
                visible: img.status !== Image.Ready && iconBox.iconPath === "" }
        }
        Column {
            id: col
            width: parent.width - 36 - 12
            spacing: 3
            Row {
                width: parent.width
                Text {
                    width: parent.width - when.implicitWidth - 24
                    text: root.entry.appName
                    elide: Text.ElideRight
                    color: Theme.textDim
                    font.family: Theme.font; font.pixelSize: Theme.fontSmall
                }
                Text {
                    id: when
                    text: { root.tick; return root.ago(root.entry.time); }
                    color: Theme.textMuted
                    font.family: Theme.font; font.pixelSize: Theme.fontSmall
                }
                Item { width: 24; height: 14
                    Glyph { anchors.centerIn: parent; text: ""; size: 10; color: cm.containsMouse ? Theme.bad : Theme.textMuted }
                    MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.closeRequested() }
                }
            }
            Text {
                width: parent.width
                text: root.entry.summary
                visible: text !== ""
                wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true
            }
            Text {
                width: parent.width
                text: root.entry.body
                visible: text !== ""
                wrapMode: Text.Wrap; maximumLineCount: root.popup ? 4 : 6; elide: Text.ElideRight
                color: Theme.textDim
                font.family: Theme.font; font.pixelSize: Theme.fontSize
            }
            Item { width: 1; height: 3; visible: actionFlow.visible || reply.visible }
            Flow {
                id: actionFlow
                width: parent.width
                spacing: 6
                visible: root.live && !root.replying && (root.entry.canReply || root.entry.markRead !== "" || root.extra.length > 0)
                Chip {
                    visible: root.entry.canReply
                    glyph: "\uf112"; label: "Reply"; primary: true
                    onClicked: root.replyRequested()
                }
                Repeater {
                    model: root.extra.slice(0, 3)
                    delegate: Chip {
                        required property var modelData
                        label: modelData.text
                        onClicked: NotificationService.invoke(root.entry.key, modelData.identifier)
                    }
                }
                Chip {
                    visible: root.entry.markRead !== ""
                    glyph: "\uf00c"; label: "Mark as read"
                    onClicked: NotificationService.markRead(root.entry.key)
                }
            }
            ReplyField {
                id: reply
                width: parent.width
                visible: root.replying && root.live
                placeholder: root.entry.replyPlaceholder || ("Reply to " + (root.entry.summary || root.entry.appName) + "…")
                onVisibleChanged: { if (visible) Qt.callLater(focusInput); else text = ""; }
                Component.onCompleted: if (visible) Qt.callLater(focusInput)
                onCancelled: root.replyClosed()
                // replying removes this card: finish UI work first, send last
                onSent: t => {
                    const key = root.entry.key;
                    root.replyClosed();
                    const ok = NotificationService.canReply(key);
                    ActivityService.toast("reply", ok ? "\uf1d8" : "\uf071", ok ? "Reply sent" : "Reply failed · notification closed", ok ? "good" : "bad");
                    NotificationService.reply(key, t);
                }
            }
        }
    }
    implicitWidth: 360
}
