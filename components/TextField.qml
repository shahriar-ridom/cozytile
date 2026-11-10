import QtQuick
import "../config"

// Single-line input. `accepted(text)` on Enter; `text` stays in sync while typing.
Rectangle {
    id: root
    property alias text: input.text
    property string placeholder: ""
    property bool mono: false
    property alias input: input
    signal accepted(string text)
    signal edited(string text)

    implicitWidth: 200; implicitHeight: 30
    radius: Theme.radiusSmall + 2
    color: Theme.surfaceAlt
    border.width: 1
    border.color: input.activeFocus ? Theme.accent : "transparent"
    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

    function clear() { input.text = ""; }
    function focusInput() { input.forceActiveFocus(); }

    TextInput {
        id: input
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 10 }
        color: Theme.text
        selectionColor: Theme.accent
        selectedTextColor: Theme.barCap
        font.family: root.mono ? Theme.fontMono : Theme.font
        font.pixelSize: Theme.fontSize
        clip: true
        selectByMouse: true
        onAccepted: root.accepted(text)
        onTextEdited: root.edited(text)
        Keys.onEscapePressed: e => { if (text !== "") { text = ""; e.accepted = true; } else { focus = false; e.accepted = false; } }
    }
    Text {
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 10 }
        visible: input.text === "" && !input.preeditText
        text: root.placeholder; elide: Text.ElideRight
        color: Theme.textMuted; font.family: input.font.family; font.pixelSize: Theme.fontSize
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; acceptedButtons: Qt.NoButton }
}
