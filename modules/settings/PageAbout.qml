import QtQuick
import Quickshell
import Quickshell.Io
import "../../config"
import "../../services"
import "../../components"

Column {
    id: page
    property var panel
    width: parent ? parent.width : 0

    property var info: ({})
    readonly property string stateDir: Settings.stateDir + "/cozytile"

    Process {
        id: probe
        command: ["sh", "-c",
            "echo \"host=$(cat /etc/hostname 2>/dev/null || hostname)\";" +
            "echo \"user=$USER\";" +
            ". /etc/os-release 2>/dev/null; echo \"os=$PRETTY_NAME\";" +
            "echo \"kernel=$(uname -r)\";" +
            "echo \"hypr=$(hyprctl version 2>/dev/null | head -1 | cut -d' ' -f2)\";" +
            "echo \"qs=$(qs --version 2>/dev/null | cut -d' ' -f2)\";" +
            "echo \"cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//')\";" +
            "echo \"gpu=$(lspci 2>/dev/null | grep -Ei 'vga|3d' | head -1 | sed 's/.*: //')\";" +
            "echo \"mem=$(awk '/MemTotal/{printf \"%.1f GiB\", $2/1048576}' /proc/meminfo)\";" +
            "echo \"up=$(uptime -p | sed 's/^up //')\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {};
                for (const l of text.split("\n")) { const i = l.indexOf("="); if (i > 0) o[l.slice(0, i)] = l.slice(i + 1); }
                page.info = o;
            }
        }
    }
    Component.onCompleted: probe.running = true

    component InfoRow: Item {
        property string k
        property string v
        width: page.width; height: 30
        Text { text: parent.k; width: 140; color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.fontSize
            anchors.verticalCenter: parent.verticalCenter }
        Text { x: 140; width: parent.width - 140; elide: Text.ElideRight; text: parent.v || "—"
            color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true
            anchors.verticalCenter: parent.verticalCenter }
    }

    Item {
        width: parent.width; height: 70
        Rectangle { id: logo; width: 52; height: 52; radius: 14; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter
            Glyph { anchors.centerIn: parent; text: ""; size: 26; color: Theme.barCap } }
        Column { x: 66; anchors.verticalCenter: parent.verticalCenter; spacing: 3
            Text { text: page.info.host || "…"; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontLarge + 2; font.bold: true }
            Text { text: (page.info.user || "") + "  ·  up " + (page.info.up || "…"); color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1 } }
    }

    Section { text: "System" }
    InfoRow { k: "OS"; v: page.info.os ?? "" }
    InfoRow { k: "Kernel"; v: page.info.kernel ?? "" }
    InfoRow { k: "CPU"; v: page.info.cpu ?? "" }
    InfoRow { k: "GPU"; v: page.info.gpu ?? "" }
    InfoRow { k: "Memory"; v: page.info.mem ?? "" }

    Section { text: "Desktop" }
    InfoRow { k: "Hyprland"; v: page.info.hypr ?? "" }
    InfoRow { k: "Quickshell"; v: page.info.qs ?? "" }
    InfoRow { k: "Theme"; v: Theme.themeLabels[Theme.name] || Theme.name }

    Section { text: "Files" }
    SettingRow {
        title: "Shell settings"; desc: page.stateDir + "/settings.json"
        IconButton { glyph: ""; label: "Open"; size: 30; onClicked: Quickshell.execDetached(["xdg-open", page.stateDir]) }
    }
    Divider {}
    SettingRow {
        title: "Generated Hyprland config"; desc: HyprConfigService.luaFile
        IconButton { glyph: ""; label: "Open"; size: 30; onClicked: Quickshell.execDetached(["xdg-open", HyprConfigService.genDir]) }
    }
}
