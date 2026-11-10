import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../services"
import "../../components"

// Settings menu: right-click the bar (or `qs -c cozytile ipc call settings toggle`).
// Every control writes straight to Settings, which persists itself.
PanelWindow {
    id: win
    screen: UiState.focusedScreen
    visible: UiState.settings || card.opacity > 0.01
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "cozytile-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: UiState.settings ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: UiState.settings = false }

    property int page: 0
    readonly property var pages: [
        { name: "Appearance", icon: "\uf53f" },
        { name: "Bar",        icon: "\uf0c9" },
        { name: "General",    icon: "\uf013" }
    ]

    // title + optional description on the left, control on the right
    component SettingRow: Item {
        id: row
        property string title: ""
        property string desc: ""
        default property alias control: slot.data
        width: parent ? parent.width : 0
        height: 46
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - slot.width - 16
            spacing: 2
            Text { text: row.title; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true }
            Text { visible: row.desc !== ""; width: parent.width; elide: Text.ElideRight; text: row.desc
                color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1 }
        }
        Item { id: slot; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width; height: childrenRect.height }
    }
    component Divider: Rectangle { width: parent ? parent.width : 0; height: 1; color: Theme.border; opacity: 0.6 }

    Rectangle {
        id: card
        width: 620; height: 430
        anchors.centerIn: parent
        radius: Theme.radius + 4
        color: Theme.popupBg
        border.width: 1; border.color: Theme.border
        opacity: UiState.settings ? 1 : 0
        scale: UiState.settings ? 1 : 0.97
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
        Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent }
        Shadowed { target: card; z: -1 }
        focus: true
        Keys.onEscapePressed: UiState.settings = false

        // ---- sidebar ----
        Rectangle {
            id: side
            width: 170; height: parent.height
            radius: Theme.radius + 4
            color: Theme.surfaceAlt
            Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: parent.radius; color: parent.color }

            Text { x: 20; y: 22; text: "Settings"; color: Theme.text
                font.family: Theme.font; font.pixelSize: Theme.fontLarge + 2; font.bold: true }

            Column {
                x: 10; y: 70; width: parent.width - 20; spacing: 4
                Repeater {
                    model: win.pages
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool on: win.page === index
                        width: parent.width; height: 36; radius: Theme.radiusSmall + 3
                        color: on ? Theme.surfaceHigh : (m.containsMouse ? Theme.hover : "transparent")
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        Rectangle { visible: parent.on; width: 3; height: 16; radius: 2; color: Theme.accent
                            anchors.verticalCenter: parent.verticalCenter; x: 0 }
                        Glyph { x: 14; anchors.verticalCenter: parent.verticalCenter; width: 16; size: 13
                            text: modelData.icon; color: parent.on ? Theme.accent : Theme.textDim }
                        Text { x: 40; anchors.verticalCenter: parent.verticalCenter; text: modelData.name
                            color: parent.on ? Theme.text : Theme.textDim
                            font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: parent.on }
                        MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: win.page = index }
                    }
                }
            }
            Text { x: 20; anchors.bottom: parent.bottom; anchors.bottomMargin: 18; text: "Esc to close"
                color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1 }
        }

        // ---- pages ----
        Item {
            anchors { left: side.right; right: parent.right; top: parent.top; bottom: parent.bottom; margins: 24; topMargin: 22 }

            Text { id: heading; text: win.pages[win.page].name; color: Theme.text
                font.family: Theme.font; font.pixelSize: Theme.fontTitle; font.bold: true }

            // Appearance
            Column {
                visible: win.page === 0
                anchors { top: heading.bottom; topMargin: 14; left: parent.left; right: parent.right }
                SettingRow {
                    title: "Theme"; desc: "Colours for the shell and synced apps"
                    Segmented {
                        model: Theme.themeNames.map(n => ({ label: Theme.themeLabels[n], value: n }))
                        current: Theme.name
                        onPicked: v => Theme.apply(v)
                    }
                }
                Divider {}
                SettingRow {
                    title: "Wallpaper colours"; desc: "Derive the theme from the current wallpaper"
                    Toggle { checked: Settings.wallpaperTheming; onToggled: v => ThemeService.setTheming(v) }
                }
                Divider {}
                SettingRow {
                    title: "Sync apps"; desc: "Re-theme kitty, starship, hyprlock and more on change"
                    Toggle { checked: Settings.syncDotfiles; onToggled: v => Settings.syncDotfiles = v }
                }
                Divider {}
                SettingRow {
                    title: "Wallpaper"; desc: "Pick a new background"
                    IconButton { glyph: "\uf03e"; label: "Choose"; size: 30; onClicked: UiState.toggle("wallpaper") }
                }
            }

            // Bar
            Column {
                visible: win.page === 1
                anchors { top: heading.bottom; topMargin: 14; left: parent.left; right: parent.right }
                SettingRow {
                    title: "Window title"; desc: "Show the focused window on the left"
                    Toggle { checked: Settings.showWindowTitle; onToggled: v => Settings.showWindowTitle = v }
                }
                Divider {}
                SettingRow {
                    title: "Workspace numbers"; desc: "Label each workspace dot"
                    Toggle { checked: Settings.showWorkspaceNumbers; onToggled: v => Settings.showWorkspaceNumbers = v }
                }
                Divider {}
                SettingRow {
                    title: "Temperature"; desc: "Show CPU temperature (wide screens)"
                    Toggle { checked: Settings.showTemp; onToggled: v => Settings.showTemp = v }
                }
                Divider {}
                SettingRow {
                    title: "Stats refresh"; desc: "How often CPU, RAM and temperature sample"
                    Segmented {
                        model: [{ label: "1 s", value: 1000 }, { label: "2 s", value: 2000 }, { label: "5 s", value: 5000 }]
                        current: Settings.statsInterval
                        onPicked: v => Settings.statsInterval = v
                    }
                }
            }

            // General
            Column {
                visible: win.page === 2
                anchors { top: heading.bottom; topMargin: 14; left: parent.left; right: parent.right }
                SettingRow {
                    title: "Do not disturb"; desc: "Silence popups; critical ones still show"
                    Toggle { checked: Settings.dnd; onToggled: v => Settings.dnd = v }
                }
                Divider {}
                SettingRow {
                    title: "OSD duration"; desc: "Volume and brightness overlay"
                    Segmented {
                        model: [{ label: "1 s", value: 1000 }, { label: "1.6 s", value: 1600 }, { label: "3 s", value: 3000 }]
                        current: Settings.osdTimeout
                        onPicked: v => Settings.osdTimeout = v
                    }
                }
                Divider {}
                SettingRow {
                    title: "Power menu"; desc: "Lock, suspend, reboot, shut down"
                    IconButton { glyph: "\uf011"; label: "Open"; size: 30; onClicked: UiState.toggle("power") }
                }
            }
        }
    }
}
