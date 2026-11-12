import QtQuick
import "../../config"
import "../../services"
import "../../components"

// Everything on the desktop itself: wallpaper and the clock drawn on it. Changes apply live.
Column {
    id: page
    property var panel
    width: parent ? parent.width : 0

    readonly property var dc: DesktopClockService

    Section { text: "Wallpaper" }
    SettingRow {
        title: "Wallpaper"; desc: "Pick a new background for each screen"
        IconButton { glyph: ""; label: "Choose"; size: 30; onClicked: UiState.toggle("wallpaper") }
    }
    Divider {}
    SettingRow {
        title: "Wallpaper folder"; desc: "Where the picker looks for images · Enter to save"
        TextField {
            width: 240
            text: (Settings.wallpaperDirs || [])[0] || ""
            placeholder: "~/Pictures/Wallpapers"
            onAccepted: t => { const d = (Settings.wallpaperDirs || []).slice(); d[0] = t.trim() || "~/Pictures/Wallpapers"; Settings.wallpaperDirs = d; }
        }
    }

    Section { text: "Desktop clock" }
    SettingRow {
        title: "Show on desktop"; desc: "A clock behind your windows. Clicks pass straight through it"
        Toggle { checked: dc.get("enabled"); onToggled: v => dc.set("enabled", v) }
    }
    Divider {}
    SettingRow {
        title: "Style"; desc: "Minimal: one big time. Stacked: hours over minutes. Analog: a round face"
        Segmented {
            model: [{ label: "Minimal", value: "minimal" }, { label: "Stacked", value: "stacked" }, { label: "Analog", value: "analog" }]
            current: dc.get("style"); onPicked: v => dc.set("style", v)
        }
    }
    Divider {}
    SettingRow {
        title: "Position"
        Dropdown {
            width: 150; title: "Clock position"
            model: [{ label: "Custom (dragged)", value: "custom" }, { label: "Center", value: "center" }, { label: "Top left", value: "top-left" }, { label: "Top right", value: "top-right" },
                    { label: "Bottom left", value: "bottom-left" }, { label: "Bottom right", value: "bottom-right" }]
            current: dc.get("position")
            opener: page.panel ? page.panel.openPicker : null
            onPicked: v => dc.set("position", v)
        }
    }
    Divider {}
    SettingRow {
        title: "Move clock"; desc: "Drag it anywhere on the desktop. Esc or Done to finish"
        IconButton { glyph: ""; label: "Move"; size: 30
            onClicked: { dc.editing = true; UiState.settings = false; } }
    }
    Divider {}
    SettingRow {
        title: "Size"
        Segmented {
            model: [{ label: "Small", value: "small" }, { label: "Medium", value: "medium" }, { label: "Large", value: "large" }]
            current: dc.get("size"); onPicked: v => dc.set("size", v)
        }
    }

    Divider {}
    SettingRow {
        title: "Font"; desc: "Default follows the interface font"
        modified: dc.get("font") !== ""
        onReset: dc.set("font", "")
        FontField {
            title: "Clock font"; value: dc.get("font"); fallback: Theme.font
            opener: page.panel ? page.panel.openFontPicker : null
            onPicked: f => dc.set("font", f)
        }
    }

    Section { text: "Time" }
    SettingRow {
        title: "24-hour time"
        Toggle { checked: dc.get("hour24"); onToggled: v => dc.set("hour24", v) }
    }
    Divider {}
    SettingRow {
        title: "Show seconds"; desc: "Updates every second"
        Toggle { checked: dc.get("seconds"); onToggled: v => dc.set("seconds", v) }
    }
    Divider {}
    SettingRow {
        title: "Show date"
        Toggle { checked: dc.get("showDate"); onToggled: v => dc.set("showDate", v) }
    }

    Section { text: "Reset" }
    SettingRow {
        title: "Reset"; desc: "Back to the default look"
        IconButton { glyph: ""; label: "Reset"; size: 30; onClicked: dc.reset() }
    }
}
