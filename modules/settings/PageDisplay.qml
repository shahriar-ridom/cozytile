import QtQuick
import "../../config"
import "../../services"
import "../../components"

// Monitors: arrangement preview + per-output mode, scale, rotation, position, VRR.
// Every change applies live and reverts after 15 s unless kept.
Column {
    id: page
    property var panel
    width: parent ? parent.width : 0

    readonly property var mons: HyprConfigService.monitorList
    property string selected: ""
    readonly property var mon: mons.find(m => m.name === selected) ?? mons[0] ?? null
    readonly property var rule: mon ? (HyprConfigService.monitors)[mon.name] ?? {} : {}
    readonly property int enabledCount: mons.filter(m => !m.disabled).length

    function set(patch) { if (mon) HyprConfigService.setMonitor(mon.name, patch); }

    readonly property var modes: {
        if (!mon) return [];
        const seen = {}, out = [{ label: "Preferred", value: "preferred" }, { label: "Highest refresh", value: "highrr" }, { label: "Highest resolution", value: "highres" }];
        for (const s of mon.availableModes || []) {
            const v = s.replace(/Hz$/, "");
            const m = v.match(/^(\d+)x(\d+)@([\d.]+)$/);
            if (!m || seen[v]) continue;
            seen[v] = true;
            out.push({ label: m[1] + " × " + m[2] + "  ·  " + (Math.round(parseFloat(m[3]) * 100) / 100) + " Hz", value: v });
        }
        return out;
    }
    readonly property string currentMode: rule.mode ?? (mon && !mon.disabled ? HyprConfigService.modeOf(mon) : "preferred")

    // ---- revert banner ----
    Rectangle {
        visible: HyprConfigService.pendingMonitor !== ""
        width: parent.width; height: visible ? 50 : 0
        radius: Theme.radius
        color: Qt.rgba(Theme.warn.r, Theme.warn.g, Theme.warn.b, 0.14)
        border.width: 1; border.color: Qt.rgba(Theme.warn.r, Theme.warn.g, Theme.warn.b, 0.5)
        Glyph { x: 14; anchors.verticalCenter: parent.verticalCenter; text: ""; size: 14; color: Theme.warn }
        Text {
            x: 40; anchors.verticalCenter: parent.verticalCenter
            text: "Keep these display settings?  Reverting in " + HyprConfigService.pendingSeconds + " s"
            color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true
        }
        Row {
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 6
            IconButton { glyph: ""; label: "Revert"; size: 30; onClicked: HyprConfigService.revertMonitor() }
            IconButton { glyph: ""; label: "Keep"; size: 30; filled: true; onClicked: HyprConfigService.keepMonitor() }
        }
    }

    // ---- night light + dimming (hyprsunset, all screens) ----
    readonly property var times: {
        const out = [];
        for (let h = 0; h < 24; h++) for (const m of ["00", "30"]) { const v = (h < 10 ? "0" : "") + h + ":" + m; out.push({ label: v, value: v }); }
        return out;
    }
    Section { text: "Night light" }
    Text {
        visible: !NightLightService.available
        width: parent.width; wrapMode: Text.WordWrap; bottomPadding: 6
        text: "hyprsunset is not installed, so night light and dimming are unavailable."
        color: Theme.warn; font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1
    }
    SettingRow {
        title: "Night light"; desc: "Warmer colours to ease eye strain · " + NightLightService.status
        Toggle { checked: NightLightService.enabled; onToggled: v => NightLightService.set({ enabled: v }) }
    }
    Divider {}
    SettingRow {
        title: "Warmth"; desc: "Lower is warmer · 6500 K is neutral"
        opacity: NightLightService.enabled ? 1 : 0.45
        Stepper { width: 130; from: 1500; to: 6500; step: 100; suffix: " K"; value: NightLightService.temperature
            onStepped: v => NightLightService.setTemperature(v) }
    }
    Divider {}
    SettingRow {
        title: "Schedule"; desc: NightLightService.scheduled ? "Turns on and off by itself every day" : "Stays on while night light is enabled"
        opacity: NightLightService.enabled ? 1 : 0.45
        Segmented {
            model: [{ label: "Always", value: false }, { label: "Scheduled", value: true }]
            current: NightLightService.scheduled
            onPicked: v => NightLightService.set({ scheduled: v })
        }
    }
    Divider { visible: NightLightService.scheduled }
    SettingRow {
        visible: NightLightService.scheduled
        title: "Active hours"
        opacity: NightLightService.enabled ? 1 : 0.45
        Row {
            spacing: 8
            Dropdown { width: 92; title: "Night light starts"; model: page.times; current: NightLightService.start
                opener: page.panel ? page.panel.openPicker : null; onPicked: v => NightLightService.set({ start: v }) }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "to"; color: Theme.textMuted
                font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1 }
            Dropdown { width: 92; title: "Night light ends"; model: page.times; current: NightLightService.end
                opener: page.panel ? page.panel.openPicker : null; onPicked: v => NightLightService.set({ end: v }) }
        }
    }
    Divider {}
    SettingRow {
        title: "Dimming"; desc: "Software brightness for all screens (gamma)"
        Stepper { width: 130; from: 20; to: 100; step: 5; suffix: " %"; value: NightLightService.gamma
            onStepped: v => NightLightService.setGamma(v) }
    }

    // ---- arrangement preview ----
    Section { text: "Arrangement" }
    Rectangle {
        id: stage
        width: parent.width; height: 150
        radius: Theme.radius
        color: Theme.surfaceAlt

        readonly property var boxes: {
            const out = [];
            for (const m of page.mons) {
                const rot = (m.transform % 2) === 1;
                const s = m.scale || 1;
                const w = (rot ? m.height : m.width) / s, h = (rot ? m.width : m.height) / s;
                out.push({ m: m, x: m.x, y: m.y, w: m.disabled ? 1920 : w, h: m.disabled ? 1080 : h });
            }
            // disabled outputs have no position: park them to the right
            let maxX = 0;
            for (const b of out) if (!b.m.disabled) maxX = Math.max(maxX, b.x + b.w);
            for (const b of out) if (b.m.disabled) { b.x = maxX + 200; b.y = 0; maxX += 200 + b.w; }
            return out;
        }
        readonly property var bounds: {
            let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
            for (const b of boxes) { x0 = Math.min(x0, b.x); y0 = Math.min(y0, b.y); x1 = Math.max(x1, b.x + b.w); y1 = Math.max(y1, b.y + b.h); }
            return boxes.length ? { x: x0, y: y0, w: x1 - x0, h: y1 - y0 } : { x: 0, y: 0, w: 1, h: 1 };
        }
        readonly property real k: Math.min((width - 40) / bounds.w, (height - 30) / bounds.h)

        Repeater {
            model: stage.boxes
            delegate: Rectangle {
                required property var modelData
                readonly property bool sel: page.mon && modelData.m.name === page.mon.name
                x: (stage.width - stage.bounds.w * stage.k) / 2 + (modelData.x - stage.bounds.x) * stage.k
                y: (stage.height - stage.bounds.h * stage.k) / 2 + (modelData.y - stage.bounds.y) * stage.k
                width: modelData.w * stage.k - 4; height: modelData.h * stage.k - 4
                radius: Theme.radiusSmall + 2
                color: sel ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : Theme.surfaceHigh
                border.width: sel ? 2 : 1
                border.color: sel ? Theme.accent : Theme.border
                opacity: modelData.m.disabled ? 0.45 : 1
                Column {
                    anchors.centerIn: parent
                    spacing: 2
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.m.name
                        color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1; font.bold: true }
                    Text { anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.m.disabled ? "off" : modelData.m.width + "×" + modelData.m.height
                        color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.fontSmall }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.selected = modelData.m.name }
            }
        }
        Text {
            visible: page.mons.length === 0
            anchors.centerIn: parent; text: "Reading monitors…"
            color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.fontSize
        }
    }

    // ---- selected output ----
    Section {
        text: page.mon ? page.mon.name + (page.mon.make ? "  ·  " + page.mon.make + " " + page.mon.model : "") : "Display"
    }
    SettingRow {
        title: "Enabled"; desc: page.enabledCount <= 1 && page.mon && !page.mon.disabled ? "The last active display can't be turned off" : "Turn this output on or off"
        Toggle {
            checked: page.mon ? !page.mon.disabled : false
            opacity: page.enabledCount <= 1 && page.mon && !page.mon.disabled ? 0.4 : 1
            onToggled: v => {
                if (!v && page.enabledCount <= 1) return;
                page.set({ disabled: v ? null : true });
            }
        }
    }
    Divider {}
    SettingRow {
        title: "Resolution & refresh rate"
        Dropdown { width: 230; title: "Resolution & refresh rate"; model: page.modes; current: page.currentMode
            opener: page.panel ? page.panel.openPicker : null; onPicked: v => page.set({ mode: v }) }
    }
    Divider {}
    SettingRow {
        title: "Scale"; desc: "Bigger text and UI on dense screens"
        Segmented {
            model: [{ label: "100%", value: 1 }, { label: "125%", value: 1.25 }, { label: "150%", value: 1.5 }, { label: "175%", value: 1.75 }, { label: "200%", value: 2 }]
            current: page.rule.scale ?? (page.mon ? Math.round(page.mon.scale * 100) / 100 : 1)
            onPicked: v => page.set({ scale: v })
        }
    }
    Divider {}
    SettingRow {
        title: "Rotation"
        Segmented {
            model: [{ label: "0°", value: 0 }, { label: "90°", value: 1 }, { label: "180°", value: 2 }, { label: "270°", value: 3 }]
            current: page.rule.transform ?? (page.mon ? page.mon.transform : 0)
            onPicked: v => page.set({ transform: v })
        }
    }
    Divider {}
    SettingRow {
        title: "Position"; desc: "Where this screen sits relative to the others"
        Dropdown {
            width: 230; title: "Position"
            model: [{ label: "Automatic", value: "auto" }, { label: "Right of others", value: "auto-right" }, { label: "Left of others", value: "auto-left" },
                    { label: "Above others", value: "auto-up" }, { label: "Below others", value: "auto-down" }, { label: "Top-left (0, 0)", value: "0x0" }]
            current: page.rule.position ?? "auto"
            opener: page.panel ? page.panel.openPicker : null; onPicked: v => page.set({ position: v })
        }
    }
    Divider {}
    SettingRow {
        title: "Adaptive sync (VRR)"; desc: "FreeSync / G-Sync; fullscreen-only avoids desktop flicker"
        Segmented {
            model: [{ label: "Off", value: 0 }, { label: "On", value: 1 }, { label: "Fullscreen", value: 2 }]
            current: page.rule.vrr ?? (page.mon && page.mon.vrr ? 1 : 0)
            onPicked: v => page.set({ vrr: v })
        }
    }
    Item { width: 1; height: 14 }
    Row {
        anchors.right: parent.right
        spacing: 6
        IconButton { glyph: ""; label: "Refresh"; size: 30; onClicked: HyprConfigService.refresh() }
        IconButton {
            visible: page.mon && (HyprConfigService.monitors)[page.mon.name] !== undefined
            glyph: ""; label: "Reset this display"; size: 30
            onClicked: HyprConfigService.resetMonitor(page.mon.name)
        }
    }
}
