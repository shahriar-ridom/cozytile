import QtQuick
import "../../config"
import "../../services"
import "../../components"

// Stage: task-oriented window groups, one Hyprland workspace each.
Column {
    id: page
    property var panel
    width: parent ? parent.width : 0
    readonly property var svc: StageService

    Section { text: "Overview" }
    SettingRow {
        title: "Hot edge"; desc: "Rest the pointer on the screen edge to open the overview. The keybind always works"
        Toggle { checked: svc.get("hotEdge"); onToggled: v => svc.set("hotEdge", v) }
    }
    Divider {}
    SettingRow {
        title: "Edge"
        Segmented {
            model: [{ label: "Left", value: "left" }, { label: "Right", value: "right" }]
            current: svc.get("side"); onPicked: v => svc.set("side", v)
        }
    }
    Divider {}
    SettingRow {
        title: "Corner radius"
        Stepper { value: svc.get("radius"); from: 0; to: 28; step: 2; onStepped: v => svc.set("radius", v) }
    }
    Divider {}
    SettingRow {
        title: "Animation speed"; desc: "1 is normal; lower is slower"
        Stepper { value: svc.get("animSpeed"); from: 0.25; to: 3; step: 0.25; decimals: 2; onStepped: v => svc.set("animSpeed", v) }
    }

    Section { text: "App rules" }
    Repeater {
        model: svc.get("rules") || []
        delegate: SettingRow {
            required property var modelData
            title: modelData.cls; desc: "opens in " + (svc.find(modelData.stage) ? svc.find(modelData.stage).name : "?")
            IconButton { glyph: ""; label: "Remove"; size: 30; onClicked: svc.removeRule(modelData.cls) }
        }
    }
    SettingRow {
        title: "Add rule"; desc: "App class (hyprctl clients) to stage name · Enter to save, e.g. firefox=Main"
        TextField {
            width: 240; placeholder: "class=Stage name"
            onAccepted: t => {
                const p = t.split("=");
                const s = svc.stages.find(x => x.name.toLowerCase() === (p[1] || "").trim().toLowerCase());
                if (s) svc.addRule(p[0], s.id);
            }
        }
    }
    Text { width: page.width; wrapMode: Text.Wrap; topPadding: 8
        text: "Super+Tab: overview (drag a window onto a desktop to move it) · Super+1-9 switch · Super+Ctrl+Tab next desktop"
        color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.fontSmall }
}
