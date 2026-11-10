import QtQuick
import Quickshell
import "../../config"
import "../../services"
import "../../components"

// hypridle timeouts (rendered to generated/hypr/hypridle.conf; hypridle restarts on change).
Column {
    id: page
    property var panel
    width: parent ? parent.width : 0

    function opts(list) {
        return [{ label: "Never", value: 0 }].concat(list.map(m => ({ label: m < 60 ? m + " min" : (m / 60) + " h", value: m * 60 })));
    }

    Section { text: "When idle" }
    SettingRow {
        title: "Lock screen after"
        Dropdown { width: 150; title: "Lock screen after"; model: page.opts([1, 2, 3, 5, 10, 15, 30, 60])
            current: HyprConfigService.idleValue("lock"); opener: page.panel ? page.panel.openPicker : null
            onPicked: v => HyprConfigService.setIdle("lock", v) }
    }
    Divider {}
    SettingRow {
        title: "Turn screen off after"
        Dropdown { width: 150; title: "Turn screen off after"; model: page.opts([1, 2, 3, 5, 6, 10, 15, 30, 60])
            current: HyprConfigService.idleValue("dpms"); opener: page.panel ? page.panel.openPicker : null
            onPicked: v => HyprConfigService.setIdle("dpms", v) }
    }
    Divider {}
    SettingRow {
        title: "Suspend after"; desc: "Sleep the machine when left alone"
        Dropdown { width: 150; title: "Suspend after"; model: page.opts([5, 10, 15, 20, 30, 45, 60, 120])
            current: HyprConfigService.idleValue("suspend"); opener: page.panel ? page.panel.openPicker : null
            onPicked: v => HyprConfigService.setIdle("suspend", v) }
    }

    Section { text: "Session" }
    SettingRow {
        title: "Lock now"
        IconButton { glyph: ""; label: "Lock"; size: 30
            onClicked: { UiState.settings = false; Quickshell.execDetached(["loginctl", "lock-session"]); } }
    }
    Divider {}
    SettingRow {
        title: "Power menu"; desc: "Lock, suspend, reboot, shut down"
        IconButton { glyph: ""; label: "Open"; size: 30; onClicked: UiState.toggle("power") }
    }
}
