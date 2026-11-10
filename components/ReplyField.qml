import QtQuick
import "../config"

// Inline reply box: Enter sends, Esc cancels. Used by the island's notification peek + panel.
Rectangle {
    id: root
    property string placeholder: "Reply…"
    property alias text: input.text
    signal sent(string text)
    signal cancelled()

    function focusInput() { input.forceActiveFocus(); }

    implicitHeight: 34
    radius: height / 2
    color: Theme.surfaceHigh
    border.width: 1
    border.color: input.activeFocus ? Theme.accent : "transparent"
    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

    function _send() { if (input.text.trim() !== "") root.sent(input.text); }

    TextInput {
        id: input
        anchors { left: parent.left; right: send.left; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 8 }
        color: Theme.text
        selectionColor: Theme.accent
        selectedTextColor: Theme.barCap
        font.family: Theme.font; font.pixelSize: Theme.fontSize
        clip: true; selectByMouse: true
        onAccepted: root._send()
        Keys.onEscapePressed: e => { e.accepted = true; root.cancelled(); }
    }
    Text {
        anchors.fill: input
        verticalAlignment: Text.AlignVCenter
        visible: input.text === "" && !input.preeditText
        text: root.placeholder; elide: Text.ElideRight
        color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.fontSize
    }
    MouseArea { anchors.fill: input; cursorShape: Qt.IBeamCursor; acceptedButtons: Qt.NoButton }
    Rectangle {
        id: send
        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 4 }
        width: 26; height: 26; radius: 13
        readonly property bool ready: input.text.trim() !== ""
        color: ready ? Theme.accent : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Glyph { anchors.centerIn: parent; text: ""; size: 11; color: send.ready ? Theme.barCap : Theme.textMuted }
        MouseArea { anchors.fill: parent; cursorShape: send.ready ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: root._send() }
    }
}
