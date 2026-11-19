import QtQuick
import "../../config"
import "../../services"
import "../../components"

// Dock: visibility, hiding, size and contents. Changes apply live.
Column {
    property var panel
    width: parent ? parent.width : 0

    Section { text: "Dock" }
    SettingRow {
        title: "Show dock"; desc: "App dock at the bottom of every screen"
        Toggle { checked: Settings.dockEnabled; onToggled: v => Settings.dockEnabled = v }
    }
    Divider {}
    SettingRow {
        title: "Hide"
        desc: "Never: windows tile above it. Intelligent: hides while a window touches it. Always: hides until you point at the bottom edge"
        Segmented {
            model: [{ label: "Never", value: "never" }, { label: "Intelligent", value: "intelli" }, { label: "Always", value: "always" }]
            current: Settings.dockHide
            onPicked: v => Settings.dockHide = v
        }
    }

    Section { text: "Size" }
    SettingRow {
        title: "Icon size"; desc: "Auto follows the screen width. Icons shrink when the dock would not fit"
        Segmented {
            model: [{ label: "Auto", value: 0 }, { label: "Small", value: 40 }, { label: "Medium", value: 52 }, { label: "Large", value: 64 }]
            current: Settings.dockIconSize
            onPicked: v => Settings.dockIconSize = v
        }
    }
    Divider {}
    SettingRow {
        title: "Magnification"; desc: "How much icons grow under the pointer"
        Segmented {
            model: [{ label: "Off", value: 1 }, { label: "Subtle", value: 1.35 }, { label: "Normal", value: 1.7 }, { label: "Large", value: 2 }]
            current: Settings.dockMagnification
            onPicked: v => Settings.dockMagnification = v
        }
    }

    Section { text: "Tools" }
    Repeater {
        model: ["clipboard", "screenshot", "notes", "system", "record"]
        Column {
            required property string modelData
            required property int index
            width: parent.width
            Divider { visible: index > 0 }
            SettingRow {
                title: DockService.tools[modelData].name
                desc: ({ clipboard: "Clipboard history: copy again, pin, clear", screenshot: "Region, window or full screen, saved and copied",
                         notes: "A scratch note that saves as you type", system: "CPU, memory, temperature, disks and network",
                         record: "Click to start or stop a screen recording (gpu-screen-recorder)" })[modelData]
                Toggle {
                    checked: Settings.dockTools.indexOf(modelData) >= 0
                    onToggled: v => Settings.dockTools = ["clipboard", "screenshot", "notes", "system", "record"].filter(t => t === modelData ? v : Settings.dockTools.indexOf(t) >= 0)
                }
            }
        }
    }
    Divider {}
    SettingRow {
        title: "Trash"; desc: "The same Trash Luma Files uses. Drop files on it to trash them"
        Toggle { checked: Settings.dockTrash; onToggled: v => Settings.dockTrash = v }
    }

    Section { text: "Folders" }
    Repeater {
        model: Settings.dockStacks
        Column {
            required property var modelData
            required property int index
            width: parent.width
            Divider { visible: index > 0 }
            SettingRow {
                title: modelData.name; desc: modelData.path === "recent" ? "Recently used files" : modelData.path
                IconButton { glyph: ""; label: "Remove"; size: 30; onClicked: DockService.removeStack(modelData.path) }
            }
        }
    }
    Divider { visible: Settings.dockStacks.length > 0 }
    SettingRow {
        title: "Add folders"; desc: "Drop a folder from your file manager onto the dock, or run: ipc call dock addStack <path>"
    }

    Section { text: "Context" }
    SettingRow {
        title: "Adapt to what I'm doing"
        desc: "Hide for fullscreen apps, show a minimal dock (screenshot, record, system) in games, open Downloads when you pause on it, dim icons that can't take a dragged file"
        Toggle { checked: Settings.dockContext; onToggled: v => Settings.dockContext = v }
    }

    Section { text: "Apps" }
    SettingRow {
        title: "Running apps"; desc: "Show open apps that aren't pinned, after a separator"
        Toggle { checked: Settings.dockShowRunning; onToggled: v => Settings.dockShowRunning = v }
    }
    Divider {}
    SettingRow {
        title: "Pinned apps"; desc: "Right-click an icon in the dock to keep or remove it"
        IconButton { glyph: ""; label: "Reset"; size: 30; onClicked: DockService.resetPinned() }
    }
}
