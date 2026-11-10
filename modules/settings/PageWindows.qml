import QtQuick
import "../../config"
import "../../services"
import "../../components"

// Hyprland look & layout. Changes apply live and are saved to cozytile_settings.lua.
Column {
    property var panel
    width: parent ? parent.width : 0

    Section { text: "Layout" }
    HyprRow {
        key: "general.layout"; title: "Tiling layout"; desc: "Dwindle splits windows in a spiral; master keeps one big window"
        Segmented { model: [{ label: "Dwindle", value: "dwindle" }, { label: "Master", value: "master" }, { label: "Scrolling", value: "scrolling" }]
            current: parent.parent.val; onPicked: v => parent.parent.set(v) }
    }
    Divider {}
    HyprRow {
        key: "general.gaps_in"; title: "Gaps between windows"
        Stepper { from: 0; to: 40; value: parent.parent.val ?? 5; suffix: " px"; onStepped: v => parent.parent.set(v) }
    }
    Divider {}
    HyprRow {
        key: "general.gaps_out"; title: "Gaps to screen edge"
        Stepper { from: 0; to: 60; value: parent.parent.val ?? 9; suffix: " px"; onStepped: v => parent.parent.set(v) }
    }
    Divider {}
    HyprRow {
        key: "misc.focus_on_activate"; title: "Focus on activate"; desc: "Jump to apps that ask for attention"
        Toggle { checked: !!parent.parent.val; onToggled: v => parent.parent.set(v) }
    }

    Section { text: "Decoration" }
    HyprRow {
        key: "decoration.rounding"; title: "Corner rounding"
        Stepper { from: 0; to: 30; value: parent.parent.val ?? 10; suffix: " px"; onStepped: v => parent.parent.set(v) }
    }
    Divider {}
    HyprRow {
        key: "general.border_size"; title: "Border width"; desc: "Cozytile is borderless by default"
        Stepper { from: 0; to: 8; value: parent.parent.val ?? 0; suffix: " px"; onStepped: v => parent.parent.set(v) }
    }
    Divider {}
    HyprRow {
        key: "decoration.active_opacity"; title: "Active window opacity"
        Stepper { from: 0.5; to: 1; step: 0.02; decimals: 2; value: parent.parent.val ?? 1; onStepped: v => parent.parent.set(v) }
    }
    Divider {}
    HyprRow {
        key: "decoration.inactive_opacity"; title: "Inactive window opacity"
        Stepper { from: 0.5; to: 1; step: 0.02; decimals: 2; value: parent.parent.val ?? 0.94; onStepped: v => parent.parent.set(v) }
    }
    Divider {}
    HyprRow {
        key: "decoration.dim_inactive"; title: "Dim inactive windows"
        Toggle { checked: !!parent.parent.val; onToggled: v => parent.parent.set(v) }
    }
    Divider {}
    HyprRow {
        key: "decoration.shadow.enabled"; title: "Shadows"
        Toggle { checked: !!parent.parent.val; onToggled: v => parent.parent.set(v) }
    }

    Section { text: "Blur" }
    HyprRow {
        id: blur
        key: "decoration.blur.enabled"; title: "Background blur"; desc: "Blur behind transparent windows and panels"
        Toggle { checked: !!parent.parent.val; onToggled: v => parent.parent.set(v) }
    }
    Divider {}
    HyprRow {
        key: "decoration.blur.size"; title: "Blur size"; opacity: blur.val ? 1 : 0.45
        Stepper { from: 1; to: 20; value: parent.parent.val ?? 6; onStepped: v => parent.parent.set(v) }
    }
    Divider {}
    HyprRow {
        key: "decoration.blur.passes"; title: "Blur passes"; desc: "More passes look smoother but cost GPU"; opacity: blur.val ? 1 : 0.45
        Stepper { from: 1; to: 6; value: parent.parent.val ?? 2; onStepped: v => parent.parent.set(v) }
    }

    Section { text: "Motion" }
    HyprRow {
        key: "animations.enabled"; title: "Animations"; desc: "Window, workspace and layer animations"
        Toggle { checked: !!parent.parent.val; onToggled: v => parent.parent.set(v) }
    }

    Item { width: 1; height: 14 }
    IconButton {
        anchors.right: parent.right
        glyph: ""; label: "Reset all Hyprland changes"; size: 30
        visible: Object.keys(HyprConfigService.hypr).length > 0
        onClicked: HyprConfigService.resetAll()
    }
}
