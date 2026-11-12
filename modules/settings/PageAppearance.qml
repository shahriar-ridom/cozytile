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

    Section { text: "Fonts" }
    SettingRow {
        title: "Interface font"; desc: "Shell, GTK apps and the lock screen"
        modified: Settings.uiFont !== ""
        onReset: { Settings.uiFont = ""; Theme.applyFonts(); }
        FontField {
            title: "Interface font"; value: Settings.uiFont; fallback: Theme.defaultFont
            opener: panel ? panel.openFontPicker : null
            onPicked: f => { Settings.uiFont = f; Theme.applyFonts(); }
        }
    }
    Divider {}
    SettingRow {
        title: "Monospace font"; desc: "Terminal (kitty) and code in GTK apps"
        modified: Settings.monoFont !== ""
        onReset: { Settings.monoFont = ""; Theme.applyFonts(); }
        FontField {
            title: "Monospace font"; value: Settings.monoFont; fallback: Theme.defaultFontMono
            opener: panel ? panel.openFontPicker : null
            onPicked: f => { Settings.monoFont = f; Theme.applyFonts(); }
        }
    }
}
