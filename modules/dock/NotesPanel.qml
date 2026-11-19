import QtQuick
import "../../config"
import "../../services"

// Quick notes: one scratch note, saved as you type (NotesService).
Column {
    id: root

    property var host

    width: 340
    spacing: 8
    readonly property bool active: host ? host.open : false
    onActiveChanged: if (active) edit.forceActiveFocus()
    Component.onCompleted: edit.forceActiveFocus()

    Text {
        x: 4
        text: "Quick Notes"
        color: Theme.text
        font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true
    }
    Rectangle {
        width: parent.width; height: 230
        radius: Theme.radius
        color: Theme.hover
        Flickable {
            id: flick
            anchors { fill: parent; margins: 10 }
            clip: true
            contentWidth: width; contentHeight: edit.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            // keep the caret in view while typing
            function follow() {
                const r = edit.cursorRectangle;
                if (r.y < contentY) contentY = r.y;
                else if (r.y + r.height > contentY + height) contentY = r.y + r.height - height;
            }
            TextEdit {
                id: edit
                width: flick.width
                text: NotesService.text
                wrapMode: TextEdit.Wrap
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.popupBg
                font.family: Theme.font; font.pixelSize: Theme.fontSize + 1
                onTextChanged: NotesService.edit(text)
                onCursorRectangleChanged: flick.follow()
                Keys.onEscapePressed: root.host.close()
                Text {
                    visible: !edit.text && !edit.activeFocus
                    text: "Jot something down…"
                    color: Theme.textMuted
                    font: edit.font
                }
            }
        }
    }
}
