pragma Singleton
import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Bluetooth
import "../config"

// Everything the island may flash: volume/mic/brightness levels, notifications, toasts (DND, theme,
// wallpaper, network, output device, bluetooth, battery) and the timer alarm.
// One ordered list; the island shows `current` (highest priority, then newest) until it expires.
Singleton {
    id: root

    // item: { key, kind: level|toast|notification|alarm, glyph, text, value (-1 = none), muted, tone, priority, ms, sticky, payload, t, expires }
    property var items: []
    readonly property var current: items.length > 0 ? items[0] : null

    // Priorities: alarm > low battery > direct interaction (levels) > toasts > notifications
    readonly property int pAlarm: 100
    readonly property int pLevel: 60
    readonly property int pToast: 40
    readonly property int pNotif: 30

    function toneColor(t) {
        return t === "warn" ? Theme.warn : t === "bad" ? Theme.bad : t === "good" ? Theme.good
             : t === "info" ? Theme.info : t === "dim" ? Theme.textMuted : Theme.accent;
    }

    function post(key, kind, p) {
        const now = Date.now();
        const it = Object.assign({ key: key, kind: kind, glyph: "", text: "", value: -1, muted: false, tone: "accent",
                                   priority: pToast, ms: 2200, sticky: false, payload: null }, p || {});
        it.t = now;
        it.expires = it.sticky ? 0 : now + it.ms;
        const rest = items.filter(i => i.key !== key);
        rest.push(it);
        rest.sort((a, b) => b.priority - a.priority || b.t - a.t);
        items = rest;
        _schedule();
    }
    function dismiss(key) { if (items.some(i => i.key === key)) { items = items.filter(i => i.key !== key); _schedule(); } }

    function toast(key, glyph, text, tone) { post(key, "toast", { glyph: glyph, text: text, tone: tone || "accent" }); }

    function level(kind, value, muted) {
        const glyph = kind === "mic" ? (muted ? "" : "")
                    : kind === "brightness" ? "" : kind === "kbd" ? ""
                    : (muted || value <= 0) ? "" : value < 0.5 ? "" : "";
        const label = kind === "mic" ? "Mic muted" : "Muted";
        post("lvl-" + kind, "level", {
            glyph: glyph, value: muted ? 0 : Math.min(1, value), muted: muted,
            text: muted ? label : Math.round(value * 100) + "%", tone: muted ? "dim" : "accent",
            priority: pLevel, ms: Settings.osdTimeout
        });
    }

    // ---- expiry: one timer aimed at the soonest deadline (no polling) ----
    function _schedule() {
        const now = Date.now();
        let next = 0;
        const live = items.filter(i => i.sticky || i.expires > now);
        if (live.length !== items.length) items = live;
        for (const i of live) if (!i.sticky && (next === 0 || i.expires < next)) next = i.expires;
        if (next > 0) { expiry.interval = Math.max(30, next - now); expiry.restart(); } else expiry.stop();
    }
    Timer { id: expiry; onTriggered: root._schedule() }

    // ---- sources --------------------------------------------------------
    property bool armed: false           // ignore the burst of changes while services connect
    Timer { interval: 3500; running: true; onTriggered: root.armed = true }

    Connections { target: AudioService; function onOsd(kind, value, muted) { root.level(kind, value, muted); } }
    Connections { target: UiState; function onOsd(kind, value, muted) { root.level(kind, value, muted); } }

    Connections {
        target: NotificationService
        function onArrived(entry) {
            if (!entry.popup) return;
            root.post("notif", "notification", { glyph: "", text: entry.summary || entry.appName,
                                                  priority: root.pNotif, ms: 5500, payload: entry });
        }
        function onUpdated(entry) {
            // keep an on-screen banner in sync (progress / text changes); do not resurrect a dismissed one
            const cur = root.items.find(i => i.key === "notif");
            if (cur && cur.payload && cur.payload.key === entry.key) {
                root.post("notif", "notification", { glyph: "\uf0f3", text: entry.summary || entry.appName,
                                                      priority: root.pNotif, ms: 4000, payload: entry });
            }
        }
        function onDndChanged() {
            if (root.armed) root.toast("dnd", NotificationService.dnd ? "" : "",
                                       NotificationService.dnd ? "Do not disturb on" : "Do not disturb off",
                                       NotificationService.dnd ? "warn" : "accent");
        }
    }
    Connections {
        target: Theme
        function onNameChanged() {
            if (root.armed) root.toast("theme", "", "Theme · " + (Theme.themeLabels[Theme.name] || Theme.name));
        }
    }
    Connections {
        target: WallpaperService
        function onApplied(monitor, path) {
            root.toast("wall", "", "Wallpaper · " + path.split("/").pop().replace(/\.[^.]+$/, ""));
        }
    }
    Connections {
        target: NetworkService
        function onKindChanged() {
            if (!root.armed) return;
            const k = NetworkService.kind;
            if (k === "none") root.toast("net", "", "Offline", "bad");
            else root.toast("net", NetworkService.icon(), "Connected · " + NetworkService.name, "good");
        }
    }
    Connections {
        target: AudioService
        function onSinkChanged() {
            if (!root.armed || !AudioService.sink) return;
            root.toast("sink", "", "Output · " + (AudioService.sink.description || AudioService.sink.nickname || AudioService.sink.name));
        }
    }
    Connections {
        target: BatteryService
        function onChargingChanged() {
            if (root.armed && BatteryService.present)
                root.toast("batt", "", BatteryService.charging ? "Charging" : "On battery", BatteryService.charging ? "good" : "warn");
        }
        function onLowChanged() {
            if (BatteryService.low)
                root.post("batt-low", "toast", { glyph: "", text: "Battery low · " + Math.round(BatteryService.percent) + "%",
                                                   tone: "bad", priority: 70, ms: 6000 });
        }
    }
    // Bluetooth devices connecting / disconnecting
    Instantiator {
        model: Bluetooth.devices
        delegate: QtObject {
            required property var modelData
            property bool linked: modelData.connected
            onLinkedChanged: if (root.armed) root.toast("bt-" + modelData.address, "",
                (modelData.name || modelData.deviceName) + (linked ? " connected" : " disconnected"), linked ? "info" : "dim")
        }
    }
}
