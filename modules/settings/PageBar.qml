import QtQuick
import "../../config"
import "../../services"
import "../../components"

Column {
    property var panel
    width: parent ? parent.width : 0

    Section { text: "Layout" }
    SettingRow {
        title: "Window title"; desc: "Show the focused window on the left"
        Toggle { checked: Settings.showWindowTitle; onToggled: v => Settings.showWindowTitle = v }
    }
    Divider {}
    SettingRow {
        title: "Workspace numbers"; desc: "Label each workspace dot"
        Toggle { checked: Settings.showWorkspaceNumbers; onToggled: v => Settings.showWorkspaceNumbers = v }
    }

    Section { text: "System stats" }
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
