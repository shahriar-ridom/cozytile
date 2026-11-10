import QtQuick
import "../../config"
import "../../services"
import "../../components"

Column {
    property var panel
    width: parent ? parent.width : 0

    Section { text: "Keyboard" }
    HyprRow {
        key: "input.kb_layout"; title: "Layouts"; desc: "Comma separated, e.g. us,de · Enter to apply"
        TextField { width: 180; mono: true; text: parent.parent.val ?? ""; placeholder: "us"
            onAccepted: t => { if (t.trim() !== "") parent.parent.set(t.trim()); } }
    }
    Divider {}
    HyprRow {
        key: "input.kb_options"; title: "XKB options"; desc: "e.g. caps:escape, grp:alt_shift_toggle · Enter to apply"
        TextField { width: 180; mono: true; text: parent.parent.val ?? ""; placeholder: "none"
            onAccepted: t => parent.parent.set(t.trim()) }
    }
    Divider {}
    HyprRow {
        key: "input.repeat_rate"; title: "Repeat rate"; desc: "Characters per second while a key is held"
        Stepper { from: 5; to: 100; value: parent.parent.val ?? 25; suffix: "/s"; onStepped: v => parent.parent.set(v) }
    }
    Divider {}
    HyprRow {
        key: "input.repeat_delay"; title: "Repeat delay"; desc: "Hold time before repeating starts"
        Stepper { from: 100; to: 1500; step: 50; value: parent.parent.val ?? 600; suffix: " ms"; onStepped: v => parent.parent.set(v) }
    }
    Divider {}
    HyprRow {
        key: "input.numlock_by_default"; title: "Num Lock on at login"
        Toggle { checked: !!parent.parent.val; onToggled: v => parent.parent.set(v) }
    }

    Section { text: "Mouse" }
    HyprRow {
        key: "input.sensitivity"; title: "Pointer speed"; desc: "-1 slowest · 0 default · 1 fastest"
        Stepper { from: -1; to: 1; step: 0.1; decimals: 1; value: parent.parent.val ?? 0; onStepped: v => parent.parent.set(v) }
    }
    Divider {}
    HyprRow {
        key: "input.accel_profile"; title: "Acceleration"; desc: "Flat is best for games"
        Segmented { model: [{ label: "Flat", value: "flat" }, { label: "Adaptive", value: "adaptive" }]
            current: parent.parent.val; onPicked: v => parent.parent.set(v) }
    }
    Divider {}
    HyprRow {
        key: "input.follow_mouse"; title: "Focus follows mouse"
        Segmented { model: [{ label: "Off", value: 0 }, { label: "Always", value: 1 }, { label: "Loose", value: 2 }]
            current: parent.parent.val; onPicked: v => parent.parent.set(v) }
    }
    Divider {}
    HyprRow {
        key: "input.natural_scroll"; title: "Natural scrolling"; desc: "Content moves with the wheel"
        Toggle { checked: !!parent.parent.val; onToggled: v => parent.parent.set(v) }
    }
    Divider {}
    HyprRow {
        key: "misc.middle_click_paste"; title: "Middle-click paste"
        Toggle { checked: !!parent.parent.val; onToggled: v => parent.parent.set(v) }
    }

    Section { text: "Touchpad" }
    HyprRow {
        key: "input.touchpad.tap_to_click"; title: "Tap to click"
        Toggle { checked: !!parent.parent.val; onToggled: v => parent.parent.set(v) }
    }
    Divider {}
    HyprRow {
        key: "input.touchpad.natural_scroll"; title: "Natural scrolling"
        Toggle { checked: !!parent.parent.val; onToggled: v => parent.parent.set(v) }
    }
    Divider {}
    HyprRow {
        key: "input.touchpad.disable_while_typing"; title: "Disable while typing"
        Toggle { checked: !!parent.parent.val; onToggled: v => parent.parent.set(v) }
    }

    Section { text: "Cursor" }
    HyprRow {
        key: "cursor.inactive_timeout"; title: "Hide when idle"; desc: "Seconds without movement · 0 never hides"
        Stepper { from: 0; to: 30; value: parent.parent.val ?? 0; suffix: " s"; onStepped: v => parent.parent.set(v) }
    }
    Divider {}
    HyprRow {
        key: "cursor.hide_on_key_press"; title: "Hide while typing"
        Toggle { checked: !!parent.parent.val; onToggled: v => parent.parent.set(v) }
    }
}
