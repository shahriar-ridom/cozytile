pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// Night light + software dimming through hyprsunset (started on demand, `hyprctl hyprsunset ...`).
//  enabled + !scheduled  -> warm all the time
//  enabled +  scheduled  -> warm between `start` and `end` (may wrap past midnight)
//  gamma < 100           -> dims every screen (useful on desktops without a backlight)
Singleton {
    id: root

    readonly property var defaults: ({ enabled: false, temperature: 4000, scheduled: false, start: "20:00", end: "07:00", gamma: 100 })
    // authoritative copy; Settings only persists it (see HyprConfigService for why)
    property var cfg: defaults
    property bool _pulled: false

    readonly property bool enabled: !!cfg.enabled
    readonly property int temperature: cfg.temperature ?? 4000
    readonly property bool scheduled: !!cfg.scheduled
    readonly property string start: cfg.start ?? "20:00"
    readonly property string end: cfg.end ?? "07:00"
    readonly property int gamma: cfg.gamma ?? 100

    property int _minute: 0                 // minutes since midnight, refreshed by the clock timer
    readonly property bool inWindow: {
        const s = toMin(start), e = toMin(end), n = _minute;
        return s === e ? true : s < e ? (n >= s && n < e) : (n >= s || n < e);
    }
    readonly property bool active: enabled && (!scheduled || inWindow)
    readonly property string status: {
        if (!enabled) return "Off";
        if (!scheduled) return "On";
        return active ? "On until " + end : "Off until " + start;
    }

    function toMin(hhmm) { const p = String(hhmm).split(":"); return (parseInt(p[0]) || 0) * 60 + (parseInt(p[1]) || 0); }

    function set(patch) {
        cfg = Object.assign({}, defaults, cfg, patch);
        persist.restart();
    }
    function toggle() { set({ enabled: !enabled }); }
    function setTemperature(k) { set({ temperature: Math.max(1000, Math.min(20000, Math.round(k))) }); }
    function setGamma(g) { set({ gamma: Math.max(10, Math.min(100, Math.round(g))) }); }

    // ---- apply (re-run after the current one if something changed meanwhile) ----
    property bool _again: false
    onActiveChanged: apply()
    onTemperatureChanged: if (active) apply()
    onGammaChanged: apply()

    function apply() {
        if (!_pulled) return;
        if (run.running) { _again = true; return; }
        run.command = ["sh", "-c", root._script, "sh", active ? "1" : "0", String(temperature), String(gamma)];
        run.running = true;
    }
    readonly property string _script: [
        "a=$1; t=$2; g=$3",
        "up() { hyprctl hyprsunset gamma 2>/dev/null | grep -q '^[0-9]'; }",
        "if ! up; then",
        "  [ \"$a\" = 1 ] || [ \"$g\" != 100 ] || exit 0",
        "  command -v hyprsunset >/dev/null || exit 3",
        "  pgrep -x hyprsunset >/dev/null || setsid -f hyprsunset -i >/dev/null 2>&1",
        "  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do sleep 0.2; up && break; done",
        "fi",
        "if [ \"$a\" = 1 ]; then hyprctl hyprsunset temperature \"$t\" >/dev/null; else hyprctl hyprsunset identity >/dev/null; fi",
        "hyprctl hyprsunset gamma \"$g\" >/dev/null"
    ].join("\n")
    property bool available: true
    Process {
        id: run
        onExited: code => {
            if (code === 3) root.available = false;
            if (root._again) { root._again = false; root.apply(); }
        }
    }

    // ---- clock (schedule) ----
    function tick() { const d = new Date(); _minute = d.getHours() * 60 + d.getMinutes(); }
    Timer { interval: 20000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.tick() }

    // ---- persistence ----
    function _pull() {
        cfg = Object.assign({}, defaults, JSON.parse(JSON.stringify(Settings.nightLight || {})), _pulled ? {} : (cfg === defaults ? {} : cfg));
        _pulled = true;
        apply();
    }
    Timer { id: persist; interval: 300; onTriggered: { if (root._pulled) Settings.nightLight = JSON.parse(JSON.stringify(root.cfg)); else restart(); } }
    Connections {
        target: Settings
        function onReadyChanged() { if (Settings.ready && !root._pulled) root._pull(); }
    }
    Component.onCompleted: { tick(); if (Settings.ready) _pull(); }
}
