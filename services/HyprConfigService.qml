pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// Hyprland side of the settings app.
//  - option overrides, monitor rules and user autostart live in Settings (settings.json)
//  - they are applied live with `hyprctl eval` and rendered to
//    ~/.config/cozytile/generated/hypr/cozytile_settings.lua, which hyprland.lua loads last,
//    so they survive reloads and restarts
//  - idle timeouts render ~/.config/cozytile/generated/hypr/hypridle.conf (startup.lua prefers it)
Singleton {
    id: root

    readonly property string genDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/cozytile/generated/hypr"
    readonly property string luaFile: genDir + "/cozytile_settings.lua"
    readonly property string idleFile: genDir + "/hypridle.conf"
    readonly property string lockCmd: Quickshell.env("HOME") + "/.config/hypr/scripts/lock.sh"

    // options the settings app reads back from the running compositor
    readonly property var options: [
        "general.layout", "general.gaps_in", "general.gaps_out", "general.border_size",
        "decoration.rounding", "decoration.active_opacity", "decoration.inactive_opacity",
        "decoration.blur.enabled", "decoration.blur.size", "decoration.blur.passes",
        "decoration.shadow.enabled", "decoration.dim_inactive", "animations.enabled",
        "misc.vrr", "misc.focus_on_activate", "misc.middle_click_paste",
        "input.kb_layout", "input.kb_options", "input.repeat_rate", "input.repeat_delay",
        "input.sensitivity", "input.accel_profile", "input.follow_mouse", "input.natural_scroll",
        "input.numlock_by_default", "input.touchpad.natural_scroll", "input.touchpad.tap_to_click",
        "input.touchpad.disable_while_typing", "cursor.inactive_timeout", "cursor.hide_on_key_press"
    ]

    // Authoritative copies. Settings (JsonAdapter) only persists them: reading a var property
    // back right after assigning it can return the previous value, which drops rapid edits.
    property var hypr: ({})
    property var monitors: ({})
    property var autostart: []
    property var idle: ({ lock: 300, dpms: 360, suspend: 1200 })
    property bool _pulled: false
    function _clone(v) { return JSON.parse(JSON.stringify(v ?? null)); }
    // edits made before settings.json finished loading are kept on top of the saved values
    function _pull() {
        hypr = Object.assign(_clone(Settings.hypr) || {}, hypr);
        monitors = Object.assign(_clone(Settings.monitors) || {}, monitors);
        autostart = (_clone(Settings.autostart) || []).concat(autostart);
        idle = Object.assign({ lock: 300, dpms: 360, suspend: 1200 }, _clone(Settings.idle) || {}, _idleTouched ? idle : {});
        _pulled = true;
    }
    property bool _idleTouched: false
    function _push() {
        Settings.hypr = _clone(hypr);
        Settings.monitors = _clone(monitors);
        Settings.autostart = _clone(autostart);
        Settings.idle = _clone(idle);
    }

    property var live: ({})          // option -> value currently in Hyprland
    property var monitorList: []     // hyprctl monitors all -j
    property bool _ready: false      // generated dir exists

    // ---- options ----
    function value(key, fallback) {
        const o = root.hypr;
        if (o[key] !== undefined) return o[key];
        if (live[key] !== undefined) return live[key];
        return fallback;
    }
    function isOverridden(key) { return (root.hypr)[key] !== undefined; }

    function set(key, v) {
        const o = Object.assign({}, root.hypr);
        o[key] = v;
        root.hypr = o;
        const l = Object.assign({}, live); l[key] = v; live = l;
        const t = {}; t[key] = v;
        eval_("hl.config(" + toLua(nest(t)) + ")");
        writeLater.restart();
    }
    // drop overrides and let hyprland.lua's own values come back
    function reset(keys) {
        const o = Object.assign({}, root.hypr);
        for (const k of keys) delete o[k];
        root.hypr = o;
        reloadAfterWrite = true;
        writeLater.restart();
    }
    function resetAll() { reset(Object.keys(root.hypr)); }

    // ---- monitors ----
    function monitorRule(name) { return (root.monitors)[name] || {}; }
    function modeOf(m) { return m.width + "x" + m.height + "@" + Number(m.refreshRate).toFixed(2); }

    // full rule for an output: stored overrides on top of its current state
    function fullRule(name) {
        const m = monitorList.find(x => x.name === name);
        const r = monitorRule(name);
        const out = { output: name };
        out.mode = r.mode ?? (m && !m.disabled ? modeOf(m) : "preferred");
        out.position = r.position ?? "auto";
        out.scale = r.scale ?? (m ? m.scale : 1);
        if (r.transform !== undefined) out.transform = r.transform;
        else if (m && m.transform) out.transform = m.transform;
        if (r.vrr !== undefined) out.vrr = r.vrr;
        if (r.disabled) out.disabled = true;
        return out;
    }

    // pending display change that reverts unless confirmed
    property string pendingMonitor: ""
    property var _pendingOld: null
    property bool _pendingHadRule: false
    property var _pendingLiveRule: null
    property int pendingSeconds: 0

    function setMonitor(name, patch) {
        if (pendingMonitor === "" || pendingMonitor !== name) {
            if (pendingMonitor !== "") keepMonitor();
            const had = (root.monitors)[name] !== undefined;
            _pendingHadRule = had;
            _pendingOld = had ? Object.assign({}, monitorRule(name)) : null;
            const m = monitorList.find(x => x.name === name);
            _pendingLiveRule = m ? { output: name, mode: m.disabled ? "preferred" : modeOf(m), position: m.x + "x" + m.y,
                                     scale: m.scale, transform: m.transform, disabled: !!m.disabled } : null;
        }
        const all = Object.assign({}, root.monitors);
        const r = Object.assign({}, all[name] || {}, patch);
        for (const k in r) if (r[k] === null) delete r[k];
        all[name] = r;
        root.monitors = all;
        applyMonitor(fullRule(name));
        pendingMonitor = name;
        pendingSeconds = 15;
        revertTick.restart();
    }
    function keepMonitor() {
        revertTick.stop();
        pendingMonitor = "";
        _pendingOld = null; _pendingLiveRule = null;
        writeLater.restart();
    }
    function revertMonitor() {
        revertTick.stop();
        const name = pendingMonitor;
        if (name === "") return;
        const all = Object.assign({}, root.monitors);
        if (_pendingHadRule) all[name] = _pendingOld; else delete all[name];
        root.monitors = all;
        applyMonitor(_pendingHadRule ? fullRule(name) : _pendingLiveRule);
        pendingMonitor = "";
        writeLater.restart();
    }
    function resetMonitor(name) {
        const all = Object.assign({}, root.monitors);
        delete all[name];
        root.monitors = all;
        reloadAfterWrite = true;
        writeLater.restart();
    }
    function applyMonitor(rule) {
        if (!rule) return;
        const r = Object.assign({}, rule);
        if (!r.disabled) delete r.disabled;
        eval_("hl.monitor(" + toLua(r) + ")");
        refreshMonitors.restart();
    }

    Timer {
        id: revertTick
        interval: 1000; repeat: true
        onTriggered: { if (--root.pendingSeconds <= 0) root.revertMonitor(); }
    }
    Timer { id: refreshMonitors; interval: 700; onTriggered: root.refresh() }

    // ---- autostart ----
    function addAutostart(name, command) {
        command = (command || "").trim();
        if (command === "") return;
        const list = (root.autostart).slice();
        list.push({ name: (name || "").trim() || command.split(/\s+/)[0].split("/").pop(), command: command, enabled: true });
        root.autostart = list;
        writeLater.restart();
    }
    function updateAutostart(i, patch) {
        const list = (root.autostart).slice();
        if (!list[i]) return;
        list[i] = Object.assign({}, list[i], patch);
        root.autostart = list;
        writeLater.restart();
    }
    function removeAutostart(i) {
        const list = (root.autostart).slice();
        list.splice(i, 1);
        root.autostart = list;
        writeLater.restart();
    }
    function moveAutostart(i, d) {
        const list = (root.autostart).slice();
        const j = i + d;
        if (j < 0 || j >= list.length) return;
        const t = list[i]; list[i] = list[j]; list[j] = t;
        root.autostart = list;
        writeLater.restart();
    }
    function runNow(command) { Quickshell.execDetached(["sh", "-c", command]); }

    // ---- idle ----
    function idleValue(k) { return (root.idle)[k] ?? ({ lock: 300, dpms: 360, suspend: 1200 })[k]; }
    function setIdle(k, seconds) {
        const o = Object.assign({ lock: 300, dpms: 360, suspend: 1200 }, root.idle);
        o[k] = seconds;
        root.idle = o;
        _idleTouched = true;
        restartIdle = true;
        writeLater.restart();
    }

    // ---- actions ----
    function reloadHyprland() { Quickshell.execDetached(["hyprctl", "reload"]); }
    function eval_(code) { Quickshell.execDetached(["hyprctl", "eval", code]); }

    function refresh() {
        if (!readOpts.running) readOpts.running = true;
        if (!readMons.running) readMons.running = true;
    }

    // ---- lua rendering ----
    function luaStr(s) {
        return "\"" + String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"").replace(/\n/g, "\\n") + "\"";
    }
    function isIdent(k) { return /^[A-Za-z_][A-Za-z0-9_]*$/.test(k); }
    function toLua(v) {
        if (typeof v === "boolean") return v ? "true" : "false";
        if (typeof v === "number") return isFinite(v) ? String(v) : "0";
        if (typeof v === "string") return luaStr(v);
        if (Array.isArray(v)) return "{ " + v.map(toLua).join(", ") + " }";
        if (v && typeof v === "object")
            return "{ " + Object.keys(v).map(k => (isIdent(k) ? k : "[" + luaStr(k) + "]") + " = " + toLua(v[k])).join(", ") + " }";
        return "nil";
    }
    function nest(flat) {
        const out = {};
        for (const key in flat) {
            const parts = key.split(".");
            let o = out;
            for (let i = 0; i < parts.length - 1; i++) o = o[parts[i]] = o[parts[i]] || {};
            o[parts[parts.length - 1]] = flat[key];
        }
        return out;
    }

    function renderLua() {
        const L = ["-- Generated by the Cozytile settings app. Edits here are overwritten;",
                   "-- change things from the settings panel (or edit ~/.local/state/cozytile/settings.json).", ""];
        const hypr = root.hypr;
        if (Object.keys(hypr).length) L.push("hl.config(" + toLua(nest(hypr)) + ")", "");
        const mons = root.monitors;
        for (const name in mons) {
            const r = mons[name] || {};
            const rule = { output: name, mode: r.mode ?? "preferred", position: r.position ?? "auto", scale: r.scale ?? 1 };
            if (r.transform !== undefined) rule.transform = r.transform;
            if (r.vrr !== undefined) rule.vrr = r.vrr;
            if (r.disabled) rule.disabled = true;
            L.push("hl.monitor(" + toLua(rule) + ")");
        }
        if (Object.keys(mons).length) L.push("");
        const auto = (root.autostart).filter(a => a && a.enabled && (a.command || "").trim() !== "");
        if (auto.length) {
            L.push("hl.on(\"hyprland.start\", function()");
            for (const a of auto) L.push("\thl.exec_cmd(" + luaStr(a.command) + ")  -- " + String(a.name || "").replace(/\n/g, " "));
            L.push("end)", "");
        }
        return L.join("\n");
    }
    function renderIdle() {
        const L = ["# Generated by the Cozytile settings app (Power & idle).",
                   "general {",
                   "    lock_cmd = " + lockCmd,
                   "    before_sleep_cmd = loginctl lock-session",
                   "    after_sleep_cmd = hyprctl dispatch dpms on",
                   "}", ""];
        const lock = idleValue("lock"), dpms = idleValue("dpms"), sus = idleValue("suspend");
        if (lock > 0) L.push("listener {", "    timeout = " + lock, "    on-timeout = loginctl lock-session", "}", "");
        if (dpms > 0) L.push("listener {", "    timeout = " + dpms, "    on-timeout = hyprctl dispatch dpms off",
                             "    on-resume = hyprctl dispatch dpms on", "}", "");
        if (sus > 0) L.push("listener {", "    timeout = " + sus, "    on-timeout = systemctl suspend", "}", "");
        return L.join("\n");
    }

    property bool reloadAfterWrite: false
    property bool restartIdle: false

    function writeNow() {
        if (!_ready || !_pulled) { writeLater.restart(); return; }
        _push();
        luaView.setText(renderLua());
        idleView.setText(renderIdle());
        if (reloadAfterWrite) { reloadAfterWrite = false; afterWrite.reload = true; afterWrite.restart(); }
        if (restartIdle) { restartIdle = false; afterWrite.idle = true; afterWrite.restart(); }
    }

    Timer { id: writeLater; interval: 350; onTriggered: root.writeNow() }
    Timer {
        id: afterWrite
        property bool reload: false
        property bool idle: false
        interval: 250
        onTriggered: {
            if (reload) { reload = false; root.reloadHyprland(); refreshMonitors.restart(); readLater.restart(); }
            if (idle) {
                idle = false;
                Quickshell.execDetached(["sh", "-c", "pkill -x hypridle; sleep 0.3; setsid -f hypridle -c \"$1\" >/dev/null 2>&1", "sh", root.idleFile]);
            }
        }
    }
    Timer { id: readLater; interval: 800; onTriggered: { if (!readOpts.running) readOpts.running = true; } }

    FileView { id: luaView; path: root.luaFile; atomicWrites: true; printErrors: false; blockLoading: false }
    FileView { id: idleView; path: root.idleFile; atomicWrites: true; printErrors: false; blockLoading: false }

    Process {
        id: mkdir
        command: ["mkdir", "-p", root.genDir]
        running: true
        onExited: { root._ready = true; writeLater.restart(); }
    }

    Connections {
        target: Settings
        function onReadyChanged() { if (Settings.ready && !root._pulled) { root._pull(); writeLater.restart(); } }
    }

    Process {
        id: readOpts
        command: ["sh", "-c", "for o; do hyprctl -j getoption \"$o\" | tr -d '\\n'; echo; done", "sh", ...root.options]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                const lines = text.split("\n");
                for (let i = 0; i < lines.length && i < root.options.length; i++) {
                    try {
                        const j = JSON.parse(lines[i]);
                        let v;
                        if (j.bool !== undefined) v = j.bool;
                        else if (j.int !== undefined) v = j.int;
                        else if (j.float !== undefined) v = Math.round(j.float * 1000) / 1000;
                        else if (j.str !== undefined) v = j.str;
                        else if (j.css !== undefined) v = parseInt(String(j.css).split(" ")[0]);
                        else if (j.custom !== undefined) v = parseInt(String(j.custom).split(" ")[0]);
                        if (v !== undefined) out[root.options[i]] = v;
                    } catch (e) {}
                }
                root.live = out;
            }
        }
    }
    Process {
        id: readMons
        command: ["hyprctl", "-j", "monitors", "all"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.monitorList = JSON.parse(text); } catch (e) {} }
        }
    }

    Component.onCompleted: { if (Settings.ready) _pull(); refresh(); }
}
