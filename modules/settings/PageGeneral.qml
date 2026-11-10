import QtQuick
import Quickshell
import "../../config"
import "../../services"
import "../../components"

Column {
    property var panel
    width: parent ? parent.width : 0

    Section { text: "Notifications" }
    SettingRow {
        title: "Do not disturb"; desc: "Silence popups; critical ones still show"
        Toggle { checked: Settings.dnd; onToggled: v => Settings.dnd = v }
    }
    Divider {}
    SettingRow {
        title: "Clear notifications"; desc: "Remove everything from the island"
        IconButton { glyph: ""; label: "Clear"; size: 30; onClicked: NotificationService.clearAll() }
    }

    Section { text: "On-screen display" }
    SettingRow {
        title: "OSD duration"; desc: "Volume and brightness overlay"
        Segmented {
            model: [{ label: "1 s", value: 1000 }, { label: "1.6 s", value: 1600 }, { label: "3 s", value: 3000 }]
            current: Settings.osdTimeout
            onPicked: v => Settings.osdTimeout = v
        }
    }

    Section { text: "Session" }
    SettingRow {
        title: "Reload Hyprland"; desc: "Re-read hyprland.lua and the settings saved here"
        IconButton { glyph: ""; label: "Reload"; size: 30; onClicked: HyprConfigService.reloadHyprland() }
    }
    Divider {}
    SettingRow {
        title: "Restart shell"; desc: "Restart Cozytile (bar, island, launcher)"
        IconButton { glyph: ""; label: "Restart"; size: 30
            onClicked: Quickshell.execDetached(["sh", "-c", "qs kill -c cozytile; sleep 0.4; setsid -f qs -c cozytile >/dev/null 2>&1"]) }
    }
}
