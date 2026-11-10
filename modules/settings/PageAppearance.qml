import QtQuick
import "../../config"
import "../../services"
import "../../components"

Column {
    property var panel
    width: parent ? parent.width : 0

    Section { text: "Theme" }
    SettingRow {
        title: "Colour scheme"; desc: "Colours for the shell and synced apps"
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
}
