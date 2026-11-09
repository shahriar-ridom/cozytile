pragma Singleton
import QtQuick
import Quickshell
import "../config"

// Countdown timer. Ticks once a second only while running; survives shell restarts (settings.timerEnd).
Singleton {
    id: root

    property int total: 0
    property int remaining: 0
    property bool running: false
    property bool paused: false
    property string label: ""
    readonly property bool active: running || paused
    readonly property real progress: total > 0 ? 1 - remaining / total : 0
    property bool alarming: false
    property real _end: 0
    property int _rings: 0

    function pad(n) { return String(n).padStart(2, "0"); }
    function format(sec) {
        sec = Math.max(0, sec);
        const h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60), s = sec % 60;
        return h > 0 ? h + ":" + pad(m) + ":" + pad(s) : pad(m) + ":" + pad(s);
    }
    // "5m", "90s", "1h30m", "25:00", "1:30:00"; a bare number means minutes. Returns seconds (0 = invalid).
    function parse(spec) {
        const s = String(spec).trim().toLowerCase();
        let m = s.match(/^(\d+):(\d{1,2})(?::(\d{1,2}))?$/);
        if (m) return m[3] !== undefined ? (+m[1]) * 3600 + (+m[2]) * 60 + (+m[3]) : (+m[1]) * 60 + (+m[2]);
        if (/^\d+(\.\d+)?$/.test(s)) return Math.round(parseFloat(s) * 60);
        let total = 0, any = false;
        const re = /(\d+(?:\.\d+)?)\s*(h|m|s)/g;      // (QML's JS engine has no String.matchAll)
        let t;
        while ((t = re.exec(s)) !== null) {
            any = true;
            total += parseFloat(t[1]) * (t[2] === "h" ? 3600 : t[2] === "m" ? 60 : 1);
        }
        return any ? Math.round(total) : 0;
    }

    function _persist() {
        Settings.timerEnd = running ? _end : 0;
        Settings.timerTotal = total;
        Settings.timerLabel = label;
        Settings.save();
    }
    function start(sec, lbl) {
        if (sec <= 0) return false;
        stopAlarm();
        total = sec; remaining = sec; label = lbl || "";
        _end = Date.now() + sec * 1000;
        running = true; paused = false;
        Settings.timerLast = sec;
        _persist();
        return true;
    }
    function pause() { if (!running) return; _tick(); running = false; paused = true; _persist(); }
    function resume() { if (!paused) return; _end = Date.now() + remaining * 1000; running = true; paused = false; _persist(); }
    function toggle() { if (running) pause(); else if (paused) resume(); }
    function stop() { running = false; paused = false; remaining = 0; total = 0; stopAlarm(); _persist(); }
    function add(sec) {
        if (!active) return;
        total += sec; remaining = Math.max(1, remaining + sec);
        if (running) _end += sec * 1000;
        _persist();
    }

    function _tick() {
        if (!running) return;
        remaining = Math.max(0, Math.ceil((_end - Date.now()) / 1000));
        if (remaining <= 0) _finish();
    }
    Timer { interval: 1000; repeat: true; running: root.running; onTriggered: root._tick() }

    function _finish() {
        running = false; paused = false;
        alarming = true; _rings = 0;
        ActivityService.post("timer", "alarm", { glyph: "", text: (label || "Timer") + " done",
                                                  tone: "warn", priority: ActivityService.pAlarm, sticky: true });
        _ring();
        Settings.timerEnd = 0; Settings.save();
    }
    function _ring() {
        Quickshell.execDetached(["sh", "-c", "pw-play /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null || paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null || true"]);
        if (++_rings < 4) ringTimer.restart(); else ringTimer.stop();
    }
    Timer { id: ringTimer; interval: 6000; onTriggered: if (root.alarming) root._ring() }
    function stopAlarm() { alarming = false; ringTimer.stop(); ActivityService.dismiss("timer"); }

    // resume a timer that was running when the shell last exited
    property bool _restored: false
    Connections { target: Settings; function onLoadedChanged() { root._restore(); } }
    Component.onCompleted: _restore()
    function _restore() {
        if (_restored || !Settings.loaded) return;
        _restored = true;
        const left = Math.ceil((Settings.timerEnd - Date.now()) / 1000);
        if (Settings.timerEnd > 0 && left > 0) {
            total = Settings.timerTotal; label = Settings.timerLabel; remaining = left;
            _end = Settings.timerEnd; running = true;
        }
    }
}
