import QtQuick
import "../../config"
import "../../services"
import "../../components"

// User autostart: any shell command, run once when Hyprland starts.
Column {
    id: page
    property var panel
    width: parent ? parent.width : 0
    spacing: 0

    readonly property var items: HyprConfigService.autostart
    property int editing: -1

    function add() {
        if (cmd.text.trim() === "") { cmd.focusInput(); return; }
        HyprConfigService.addAutostart(nameField.text, cmd.text);
        cmd.clear(); nameField.clear();
    }

    Text {
        width: parent.width; wrapMode: Text.WordWrap
        text: "Commands here run once each time you log in to Hyprland. Add an app, a script, or any shell command. Built-in services (bar, clipboard, polkit) live in config/startup.lua."
        color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1
    }

    Section { text: "Add" }
    Rectangle {
        width: parent.width; height: addCol.implicitHeight + 24
        radius: Theme.radius; color: Theme.surfaceAlt
        Column {
            id: addCol
            x: 12; y: 12; width: parent.width - 24; spacing: 8
            Row {
                width: parent.width; spacing: 8
                TextField { id: nameField; width: 150; placeholder: "Name (optional)"; color: Theme.surface
                    onAccepted: cmd.focusInput() }
                TextField { id: cmd; width: parent.width - 158; mono: true; placeholder: "Command, e.g.  discord --start-minimized"; color: Theme.surface
                    onAccepted: page.add() }
            }
            Row {
                spacing: 6
                IconButton { glyph: ""; label: "Add command"; size: 30; filled: true; onClicked: page.add() }
                IconButton {
                    glyph: ""; label: "Pick an app"; size: 30
                    onClicked: page.panel.openAppPicker(e => HyprConfigService.addAutostart(e.name, e.command))
                }
                IconButton {
                    glyph: ""; label: "Test run"; size: 30; visible: cmd.text.trim() !== ""
                    onClicked: HyprConfigService.runNow(cmd.text)
                }
            }
        }
    }

    Section { text: "Startup items · " + page.items.length }
    Text {
        visible: page.items.length === 0
        width: parent.width; height: 60; verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter
        text: "Nothing yet. Added items appear here and start at your next login."
        color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.fontSize
    }
    Repeater {
        model: page.items
        delegate: Column {
            id: entry
            required property var modelData
            required property int index
            readonly property bool editingThis: page.editing === index
            function save() {
                if (eCmd.text.trim() !== "")
                    HyprConfigService.updateAutostart(index, { name: eName.text.trim(), command: eCmd.text.trim() });
                page.editing = -1;
            }
            width: page.width

            Item {
                width: parent.width; height: entry.editingThis ? 92 : 54
                Toggle {
                    id: tg
                    x: 0; y: 17
                    checked: entry.modelData.enabled !== false
                    onToggled: v => HyprConfigService.updateAutostart(entry.index, { enabled: v })
                }
                Column {
                    visible: !entry.editingThis
                    x: tg.width + 14; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - actions.width - 10; spacing: 2
                    opacity: entry.modelData.enabled !== false ? 1 : 0.5
                    Text { width: parent.width; elide: Text.ElideRight; text: entry.modelData.name || entry.modelData.command
                        color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true }
                    Text { width: parent.width; elide: Text.ElideMiddle; text: entry.modelData.command
                        color: Theme.textMuted; font.family: Theme.fontMono; font.pixelSize: Theme.fontSmall + 1 }
                }
                Column {
                    visible: entry.editingThis
                    x: tg.width + 14; y: 10
                    width: parent.width - x - actions.width - 10; spacing: 6
                    TextField { id: eName; width: parent.width; text: entry.modelData.name || ""; placeholder: "Name"
                        onAccepted: eCmd.focusInput() }
                    TextField { id: eCmd; width: parent.width; mono: true; text: entry.modelData.command; placeholder: "Command"
                        onAccepted: entry.save() }
                }
                Row {
                    id: actions
                    anchors { right: parent.right; top: parent.top; topMargin: 12 }
                    spacing: 2
                    IconButton { visible: !entry.editingThis; glyph: ""; size: 30; onClicked: HyprConfigService.runNow(entry.modelData.command) }
                    IconButton { visible: !entry.editingThis; glyph: ""; size: 30; onClicked: page.editing = entry.index }
                    IconButton { visible: entry.editingThis; glyph: ""; size: 30; filled: true
                        onClicked: entry.save() }
                    IconButton { visible: entry.editingThis; glyph: ""; size: 30; onClicked: page.editing = -1 }
                    IconButton { visible: !entry.editingThis; glyph: ""; size: 30; opacity: entry.index > 0 ? 1 : 0.3
                        onClicked: HyprConfigService.moveAutostart(entry.index, -1) }
                    IconButton { visible: !entry.editingThis; glyph: ""; size: 30; opacity: entry.index < page.items.length - 1 ? 1 : 0.3
                        onClicked: HyprConfigService.moveAutostart(entry.index, 1) }
                    IconButton { visible: !entry.editingThis; glyph: ""; size: 30
                        onClicked: { HyprConfigService.removeAutostart(entry.index); page.editing = -1; } }
                }
            }
            Divider { visible: entry.index < page.items.length - 1 }
        }
    }
}
