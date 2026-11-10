import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../config"
import "../../services"
import "../../components"
import "Search.js" as S

// Spotlight-style launcher: apps, open windows, calculator and unit/currency conversion, files,
// system actions, clipboard history, web search and a shell prompt, in one box.
//
// Prefixes:  >cmd run a shell command   /name find files only   clip [text] clipboard history
//            :name emoji   g|yt|gh|w|so|aur|aw|mdn <text> search that site
// Keys:      Up/Down, Ctrl+J/K, Ctrl+N/P, Tab move   Enter run   Shift+Enter secondary (file: show folder)
//            Alt+1..9 run the Nth result   Esc close
PanelWindow {
    id: win
    screen: UiState.focusedScreen
    visible: UiState.launcher || card.opacity > 0.01
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "cozytile-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: UiState.launcher ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property string home: Quickshell.env("HOME")
    readonly property int maxListH: 396
    property string query: ""
    property int index: 0
    // last real pointer position; hover ignored unless pointer truly moved (list scrolling/filtering under a still mouse must not steal selection)
    property real lastMouseX: -1
    property real lastMouseY: -1
    property string selKey: ""
    property string armedId: ""
    property var hist: ({})

    // async provider results
    property var calcAsync: null
    property var fileHits: []
    property string fileKey: ""
    property var clipLines: []
    property bool clipLoaded: false

    // ---- emoji ----------------------------------------------------------------
    FileView {
        id: emojiFile
        path: Quickshell.shellPath("modules/launcher/emoji.json")
        blockLoading: true
        printErrors: false
    }
    property var emojiData: null
    function emojis() {
        if (!emojiData) { try { emojiData = JSON.parse(emojiFile.text()); } catch (e) { emojiData = []; } }
        return emojiData;
    }
    function emojiRow(e) {
        return row("emoji", "emo:" + e[0], e[1], { emoji: e[0], subtitle: e[2], hint: "Copy" });
    }
    // name/alias match score, 0 = none; frequently used emoji float up
    function emojiScore(e, q) {
        const sa = e[3] ? S.score(e[3], q) : 0;  // hand-picked slang/popular aliases win ties
        let s = Math.max(S.score(e[1], q), sa ? sa + 25 : 0);
        if (s === 0 && q.length >= 3 && e[2].toLowerCase().includes(q)) s = 20;
        if (s === 0) return 0;
        const h = hist["emo:" + e[0]];
        return s + (h ? Math.min(30, h.n * 4) : 0);
    }
    function emojiRows(term, limit) {
        const data = emojis();
        if (!term) {  // recents first, then the smileys
            const used = data.filter(e => hist["emo:" + e[0]]).sort((a, b) => hist["emo:" + b[0]].t - hist["emo:" + a[0]].t);
            return used.concat(data.filter(e => !hist["emo:" + e[0]])).slice(0, limit).map(emojiRow);
        }
        return data.map(e => ({ e: e, s: emojiScore(e, term) })).filter(x => x.s > 0)
            .sort((a, b) => b.s - a.s).slice(0, limit).map(x => emojiRow(x.e));
    }

    // ---- system actions -----------------------------------------------------
    readonly property var actions: [
        { id: "lock", title: "Lock screen", kw: "lock screen secure", glyph: "",
          run: () => Quickshell.execDetached(["sh", "-c", "command -v hyprlock >/dev/null && hyprlock || loginctl lock-session"]) },
        { id: "sleep", title: "Sleep", kw: "sleep suspend", glyph: "",
          run: () => Quickshell.execDetached(["systemctl", "suspend"]) },
        { id: "logout", title: "Log out", kw: "log out logout exit session", glyph: "", confirm: true, danger: true,
          run: () => Quickshell.execDetached(["sh", "-c", "hyprctl dispatch exit || loginctl terminate-user $USER"]) },
        { id: "restart", title: "Restart", kw: "restart reboot", glyph: "", confirm: true, danger: true,
          run: () => Quickshell.execDetached(["systemctl", "reboot"]) },
        { id: "shutdown", title: "Shut down", kw: "shut down shutdown power off poweroff", glyph: "", confirm: true, danger: true,
          run: () => Quickshell.execDetached(["systemctl", "poweroff"]) },
        { id: "theme", title: "Switch theme", kw: "theme colors appearance dark everforest sakura wallpaper", glyph: "", stay: true,
          run: () => Theme.next() },
        { id: "wallpaper", title: "Choose wallpaper", kw: "wallpaper background picture", glyph: "",
          run: () => UiState.toggle("wallpaper") },
        { id: "dnd", title: "Toggle Do Not Disturb", kw: "do not disturb dnd notifications silence", glyph: "",
          run: () => NotificationService.toggleDnd() },
        { id: "mute", title: "Toggle mute", kw: "mute unmute volume sound audio", glyph: "",
          run: () => { if (AudioService.ready) AudioService.sink.audio.muted = !AudioService.muted; } },
        { id: "wifi-on", title: "Turn Wi-Fi on", kw: "wifi wi-fi wireless network on", glyph: "",
          run: () => Quickshell.execDetached(["nmcli", "radio", "wifi", "on"]) },
        { id: "wifi-off", title: "Turn Wi-Fi off", kw: "wifi wi-fi wireless network off", glyph: "",
          run: () => Quickshell.execDetached(["nmcli", "radio", "wifi", "off"]) },
        { id: "bt-on", title: "Turn Bluetooth on", kw: "bluetooth on", glyph: "",
          run: () => Quickshell.execDetached(["bluetoothctl", "power", "on"]) },
        { id: "bt-off", title: "Turn Bluetooth off", kw: "bluetooth off", glyph: "",
          run: () => Quickshell.execDetached(["bluetoothctl", "power", "off"]) },
        { id: "clip", title: "Clipboard history", kw: "clipboard history paste copied", glyph: "", stay: true,
          run: () => { input.text = "clip "; } }
    ]

    // ---- row builders -------------------------------------------------------
    function row(kind, key, title, extra) {
        return Object.assign({ kind: kind, key: key, title: title, selectable: true, h: 46, hint: "Open" }, extra || {});
    }
    function appRow(e) {
        return row("app", "app:" + e.id, e.name, { subtitle: e.comment || e.genericName || "", icon: e.icon, entry: e });
    }
    function windows() {
        const out = [];
        for (const t of Hyprland.toplevels.values) {
            const cls = (t.lastIpcObject && t.lastIpcObject["class"]) || "";
            if (!cls && !t.title) continue;
            out.push({ address: t.address, title: t.title || cls, cls: cls, ws: t.workspace ? t.workspace.name : "" });
        }
        return out;
    }
    function winRow(w) {
        const de = w.cls ? DesktopEntries.heuristicLookup(w.cls) : null;
        return row("window", "win:" + w.address, w.title, {
            subtitle: (w.cls || "Window") + (w.ws ? ", workspace " + w.ws : ""), alwaysSub: true,
            icon: de ? de.icon : w.cls.toLowerCase(), addr: w.address, hint: "Switch to"
        });
    }
    function actionRow(a) {
        const armed = win.armedId === a.id;
        return row("action", "act:" + a.id, armed ? a.title + "?" : a.title, {
            glyph: a.glyph, action: a, danger: !!a.danger, armed: armed,
            subtitle: armed ? "Press Enter again to confirm" : "", hint: a.confirm ? "Confirm" : (a.stay ? "Open" : "Run")
        });
    }
    function fileRow(f) {
        return row("file", "file:" + f.path, S.basename(f.path), {
            subtitle: S.shortPath(S.dirname(f.path), win.home), alwaysSub: true, path: f.path,
            glyph: f.isDir ? "\uf07b" : "\uf15b", hint: "Open"
        });
    }
    function fmtAsync(q) { return calcAsync && calcAsync.key === q ? calcAsync : null; }
    function calcRow(q, title, copy) {
        return row("calc", "calc", title, { subtitle: q.replace(/^=\s*/, ""), glyph: "", copy: copy, h: 68, hint: "Copy" });
    }

    // ---- the whole result list ----------------------------------------------
    function build() {
        const raw = query.trim();
        const q = raw.toLowerCase();
        const sections = [];
        function add(title, rows) { if (rows.length) sections.push({ title: title, rows: rows }); }
        const wins = windows();

        function appScore(e) {
            let s = S.score(e.name, q);
            if (s === 0) {
                const rest = ((e.genericName || "") + " " + (e.comment || "") + " " + (e.keywords || []).join(" ") + " " + (e.id || "")).toLowerCase();
                if (q.length >= 2 && rest.includes(q)) s = 25;
            }
            if (s === 0) return 0;
            const h = hist["app:" + e.id];
            if (h) s += Math.min(25, h.n * 3) + (Date.now() - h.t < 7 * 864e5 ? 5 : 0);
            return s;
        }
        const entries = DesktopEntries.applications.values.filter(e => !e.noDisplay);

        if (raw === "") {
            const rank = e => { const h = hist["app:" + e.id]; return h ? h.n * 1e13 + h.t : 0; };
            const byUse = entries.slice().sort((a, b) => rank(b) - rank(a) || a.name.localeCompare(b.name));
            add("Suggested", byUse.slice(0, 5).map(appRow));
            add("Open windows", wins.slice(0, 4).map(winRow));
        } else if (raw[0] === ">") {
            const cmd = raw.slice(1).trim();
            add("", [row("run", "run", cmd ? "Run “" + cmd + "”" : "Type a shell command", {
                glyph: "", cmd: cmd, hint: cmd ? "Run" : "", selectable: !!cmd })]);
        } else if (/^(clip|cb|clipboard)\s/i.test(raw)) {
            const term = raw.replace(/^\S+\s*/, "").toLowerCase();
            const rows = [];
            for (const line of clipLines) {
                const tab = line.indexOf("\t");
                if (tab < 0) continue;
                const id = line.slice(0, tab), text = line.slice(tab + 1);
                if (!/^\d+$/.test(id) || (term && !text.toLowerCase().includes(term))) continue;
                rows.push(row("clip", "clip:" + id, text.replace(/\s+/g, " ").slice(0, 90), {
                    glyph: "", clipId: id, subtitle: "Clipboard", hint: "Copy" }));
                if (rows.length >= 40) break;
            }
            if (!rows.length)
                rows.push(row("clip", "clip:none", clipLoaded ? "Nothing in clipboard history" : "Loading clipboard history", { glyph: "\uf328", selectable: false, hint: "" }));
            add("Clipboard", rows);
        } else if (raw[0] === ":") {
            add("Emoji", emojiRows(raw.slice(1).trim().toLowerCase(), 40));
        } else if (raw[0] === "/" || raw.startsWith("~/")) {
            add("Files", fileRows(raw.replace(/^~?\//, ""), 30));
        } else {
            const b = S.bang(raw);
            if (b) {
                add("", [row("web", "web", "Search " + b.engine.name + " for “" + b.term + "”", {
                    glyph: "", url: S.searchUrl(b.engine, b.term), hint: "Open" })]);
            } else {
                // calculator / converter
                let calc = null;
                if (S.mathy(raw)) {
                    const expr = raw.replace(/^=\s*/, "");
                    const v = S.safeEval(expr);
                    if (v !== null && (/[^\d.\s]/.test(expr.replace(/^[-+]/, "")) || raw[0] === "="))
                        calc = calcRow(raw, S.fmtNumber(v), String(Number(v.toPrecision(12))));
                    else if (v === null) { const a = fmtAsync(raw); if (a) calc = calcRow(raw, a.title, a.copy); }
                }
                if (calc) add("Calculator", [calc]);

                const apps = entries.map(e => ({ e: e, s: appScore(e) })).filter(x => x.s > 0)
                    .sort((a, b) => b.s - a.s || a.e.name.localeCompare(b.e.name)).slice(0, 6).map(x => appRow(x.e));
                add("Applications", apps);

                add("Windows", wins.filter(w => S.score(w.title, q) > 0 || S.score(w.cls, q) > 0).slice(0, 4).map(winRow));

                if (q.length >= 2)
                    add("Actions", actions.filter(a => S.score(a.title, q) > 0 || a.kw.includes(q)).slice(0, 4).map(actionRow));

                if (q.length >= 2 && !calc) {
                    const em = emojis().map(e => ({ e: e, s: emojiScore(e, q) })).filter(x => x.s >= 60)
                        .sort((a, b) => b.s - a.s).slice(0, 3).map(x => emojiRow(x.e));
                    add("Emoji", em);
                }

                if (!calc && q.length >= 2) add("Files", fileRows(raw, 6));

                const url = S.asUrl(raw);
                if (url) add("Web", [row("web", "web", "Open " + url.replace(/^https?:\/\//, ""), { glyph: "", url: url, hint: "Open" })]);
                else if (!calc || sections.length > 1)
                    add("Web", [row("web", "web", "Search the web for “" + raw + "”", {
                        glyph: "", url: S.searchUrl(S.defaultEngine(), raw), hint: "Open" })]);
            }
        }

        // flatten, with quiet headers only when more than one section is showing
        const rows = [];
        let height = 0;
        const showHeaders = sections.length > 1;
        for (const s of sections) {
            if (showHeaders && s.title) { rows.push({ kind: "header", key: "h:" + s.title, title: s.title, h: 30, selectable: false }); height += 30; }
            for (const r of s.rows) { rows.push(r); height += r.h; }
        }
        return { rows: rows, height: height };
    }

    function fileRows(term, limit) {
        const words = term.trim().toLowerCase().split(/\s+/).filter(w => w);
        if (!words.length) return [];
        const hits = fileHits.filter(f => { const p = f.path.toLowerCase(); return words.every(w => p.includes(w)); });
        const q = words.join(" ");
        return hits.map(f => ({ f: f, s: S.score(S.basename(f.path), q) + (f.isDir ? 3 : 0) - f.path.split("/").length * 0.6 }))
            .sort((a, b) => b.s - a.s || a.f.path.length - b.f.path.length).slice(0, limit).map(x => fileRow(x.f));
    }

    readonly property var built: build()
    readonly property var rows: built.rows

    onRowsChanged: {
        let i = rows.findIndex(r => r.selectable && r.key === selKey);
        if (i < 0) i = rows.findIndex(r => r.selectable);
        index = i < 0 ? 0 : i;
        if (rows.length) selKey = rows[index].key;
        list.positionViewAtIndex(index, ListView.Contain);
    }
    onIndexChanged: {
        if (rows[index]) selKey = rows[index].key;
        armedId = rows[index] && rows[index].armed ? armedId : "";
        if (list.count > 0) list.positionViewAtIndex(index, index <= 1 ? ListView.Beginning : ListView.Contain);
    }

    function move(d) {
        let i = index;
        for (;;) {
            i += d;
            if (i < 0 || i >= rows.length) return;
            if (rows[i].selectable) { index = i; return; }
        }
    }

    // ---- running things -----------------------------------------------------
    function record(key) {
        const h = hist[key] || { n: 0, t: 0 };
        const next = Object.assign({}, hist);
        next[key] = { n: h.n + 1, t: Date.now() };
        hist = next;
        saveTimer.restart();
    }
    function activate(r, secondary) {
        if (!r || !r.selectable) return;
        switch (r.kind) {
        case "app": record(r.key); UiState.launcher = false; r.entry.execute(); break;
        case "window": {
            UiState.launcher = false;
            const a = r.addr.startsWith("0x") ? r.addr : "0x" + r.addr;
            Hyprland.dispatch(Hyprland.usingLua ? "hl.dsp.focus({ window = \"address:" + a + "\" })" : "focuswindow address:" + a);
            break; }
        case "action": {
            const a = r.action;
            if (a.confirm && armedId !== a.id) { armedId = a.id; return; }
            if (!a.stay) UiState.launcher = false;
            a.run();
            break; }
        case "file": record(r.key); UiState.launcher = false;
            Quickshell.execDetached(["xdg-open", secondary ? S.dirname(r.path) : r.path]); break;
        case "emoji": record(r.key); UiState.launcher = false; Quickshell.execDetached(["wl-copy", r.emoji]); break;
        case "calc": UiState.launcher = false; Quickshell.execDetached(["wl-copy", r.copy]); break;
        case "clip": UiState.launcher = false;
            Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", r.clipId]); break;
        case "web": UiState.launcher = false; Quickshell.execDetached(["xdg-open", r.url]); break;
        case "run": UiState.launcher = false; Quickshell.execDetached(["sh", "-c", r.cmd]); break;
        }
    }
    function nthSelectable(n) { return rows.filter(r => r.selectable)[n]; }

    // ---- async providers ----------------------------------------------------
    Runner {
        id: calcRunner
        onResult: (key, text) => {
            let t = text.split("\n")[0].trim();
            if (!t) return;
            const meta = win.calcMeta;
            if (t[0] === "#") {
                const n = parseFloat(t.slice(1));
                if (isNaN(n) || !meta) return;
                const s = S.fmtNumber(Number(n.toPrecision(8))) + " " + meta.target;
                win.calcAsync = { key: key, title: s, copy: s };
            } else {
                if (/["]|error|warning/i.test(t) || t[0] === "(" || t === key.replace(/^=\s*/, "")) return;
                t = t.replace(/(\d+\.\d{6})\d+/g, "$1");
                win.calcAsync = { key: key, title: t, copy: t };
            }
        }
    }
    property var calcMeta: null
    Runner {
        id: fileRunner
        onResult: (key, text) => {
            const hits = [];
            for (const p of text.split("\n")) {
                if (!p) continue;
                const isDir = p.endsWith("/");
                hits.push({ path: isDir ? p.slice(0, -1) : p, isDir: isDir });
            }
            win.fileHits = hits; win.fileKey = key;
        }
    }
    Runner {
        id: clipRunner
        onResult: (key, text) => { win.clipLines = text.split("\n").filter(l => l); win.clipLoaded = true; }
    }

    Timer {
        id: debounce
        interval: 140
        onTriggered: {
            const raw = win.query.trim();
            if (/^(clip|cb|clipboard)\s/i.test(raw)) {
                if (!win.clipLoaded) clipRunner.request("clip", ["cliphist", "list"]);
                return;
            }
            if (raw === "" || raw[0] === ">" || S.bang(raw)) { fileRunner.cancel(); calcRunner.cancel(); return; }

            // maths / conversion
            if (S.mathy(raw) && S.safeEval(raw.replace(/^=\s*/, "")) === null) {
                const conv = S.parseConversion(raw);
                if (conv && !S.affine(raw)) {
                    win.calcMeta = { target: conv.target };
                    calcRunner.request(raw, ["sh", "-c",
                        "r=$(qalc -t \"$1\" 2>/dev/null); case \"$r\" in \"\"|*[a-zA-Z\\\"]*) qalc -t \"$2\" 2>/dev/null;; *) echo \"#$r\";; esac",
                        "sh", "(" + conv.left + ")/(1 " + conv.target + ")", conv.left + " to " + conv.target]);
                } else {
                    win.calcMeta = null;
                    const prep = S.normTemp(raw.replace(/^=\s*/, "")).replace(/%\s+of\s+/i, "% * ").replace(/\s+in\s+/i, " to ");
                    calcRunner.request(raw, ["qalc", "-t", prep]);
                }
            } else calcRunner.cancel();

            // files
            const term = (raw[0] === "/" ? raw.slice(1) : raw.startsWith("~/") ? raw.slice(2) : raw).trim();
            if (term.length >= 2 && !(S.mathy(raw) && S.safeEval(raw.replace(/^=\s*/, "")) !== null))
                fileRunner.request(term.toLowerCase(), ["timeout", "2", "fd", "-i", "-a", "--max-results", "80", "--type", "f", "--type", "d",
                    "-E", "node_modules", "-E", ".git", "-E", ".cache", "-E", "target", "-E", "__pycache__", "-E", ".steam", "-E", "*cache*", "-E", "*Cache*", "-E", "*webcache*", "-E", "Saved",
                    S.regexFromQuery(term), win.home, "/mnt/storage"]);
        }
    }

    // ---- history persistence ------------------------------------------------
    FileView {
        id: histFile
        path: win.home + "/.local/state/cozytile/launcher-history.json"
        blockLoading: true
        printErrors: false
    }
    Timer { id: saveTimer; interval: 600; onTriggered: histFile.setText(JSON.stringify(win.hist)) }
    Component.onCompleted: { try { const h = JSON.parse(histFile.text()); if (h && typeof h === "object") hist = h; } catch (e) {} }

    Connections {
        target: UiState
        function onLauncherChanged() {
            if (UiState.launcher) {
                win.selKey = ""; win.armedId = ""; win.query = ""; win.calcAsync = null; win.fileHits = []; win.fileKey = "";
                win.clipLines = []; win.clipLoaded = false;
                input.text = UiState.launcherQuery; UiState.launcherQuery = ""; input.forceActiveFocus();
                Hyprland.refreshToplevels();
            }
        }
    }

    // ---- view ---------------------------------------------------------------
    // invisible: click outside closes, nothing is dimmed
    MouseArea { anchors.fill: parent; onClicked: UiState.launcher = false }

    Rectangle {
        id: card
        readonly property int listH: Math.min(win.maxListH, Math.max(win.built.height, 56))
        width: Math.min(600, parent.width - 40)
        height: 64 + 1 + listH + 18
        Behavior on height { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.18 + (UiState.launcher ? 0 : -12)
        radius: Theme.radius + 6
        color: Theme.launcherBg
        border.width: 1; border.color: Theme.border
        opacity: UiState.launcher ? 1 : 0
        scale: UiState.launcher ? 1 : 0.97
        transformOrigin: Item.Top
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent }  // swallow clicks

        Shadowed { target: card; z: -1 }

        Item {  // search row: bare text on the card
            id: field
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 64
            Glyph {
                x: 22; anchors.verticalCenter: parent.verticalCenter
                text: win.query.startsWith(">") ? "" : ""; size: 16
                color: input.text.length ? Theme.accent : Theme.textMuted
                Behavior on color { ColorAnimation { duration: Theme.animNormal } }
            }
            TextInput {
                id: input
                anchors { left: parent.left; right: parent.right; leftMargin: 54; rightMargin: 24; verticalCenter: parent.verticalCenter }
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.barCap
                font.family: Theme.font; font.pixelSize: 19
                clip: true
                onTextChanged: { win.selKey = ""; win.armedId = ""; win.query = text; debounce.restart(); }
                Keys.onEscapePressed: UiState.launcher = false
                Keys.onDownPressed: win.move(1)
                Keys.onUpPressed: win.move(-1)
                Keys.onTabPressed: win.move(1)
                Keys.onBacktabPressed: win.move(-1)
                Keys.onPressed: e => {
                    if (e.modifiers & Qt.AltModifier && e.key >= Qt.Key_1 && e.key <= Qt.Key_9) {
                        win.activate(win.nthSelectable(e.key - Qt.Key_1), false); e.accepted = true;
                    } else if (e.modifiers & Qt.ControlModifier) {
                        if (e.key === Qt.Key_J || e.key === Qt.Key_N) { win.move(1); e.accepted = true; }
                        else if (e.key === Qt.Key_K || e.key === Qt.Key_P) { win.move(-1); e.accepted = true; }
                    } else if (e.key === Qt.Key_PageDown) { for (let i = 0; i < 6; i++) win.move(1); e.accepted = true; }
                    else if (e.key === Qt.Key_PageUp) { for (let i = 0; i < 6; i++) win.move(-1); e.accepted = true; }
                }
                Keys.onReturnPressed: e => win.activate(win.rows[win.index], !!(e.modifiers & Qt.ShiftModifier))
                Keys.onEnterPressed: e => win.activate(win.rows[win.index], !!(e.modifiers & Qt.ShiftModifier))
                Text {
                    visible: !input.text && !input.preeditText
                    text: "Search apps, files, and more"
                    color: Theme.textMuted
                    font: input.font
                }
            }
        }

        Rectangle {
            id: divider
            anchors { top: field.bottom; left: parent.left; right: parent.right; leftMargin: 20; rightMargin: 20 }
            height: 1
            color: Theme.slash
        }

        ListView {
            id: list
            anchors { top: divider.bottom; left: parent.left; right: parent.right; margins: 8; topMargin: 8 }
            height: card.listH
            clip: true
            model: win.rows
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 400
            currentIndex: win.index
            highlightMoveDuration: 140
            highlightMoveVelocity: -1
            highlightResizeDuration: 140
            highlightFollowsCurrentItem: true
            // gliding selection drawn with the bar's own segment shape (round left, S-curve right)
            highlight: Item {
                width: list.width
                height: list.currentItem ? list.currentItem.height : 46
                visible: list.currentItem && !list.currentItem.header
                Segment {
                    anchors.fill: parent
                    tone: Theme.surfaceHigh
                    leftEdge: "round"; rightEdge: "curve"
                    radius: Theme.radius
                }
                Rectangle {
                    x: 6; width: 3; height: 16; radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: win.rows[win.index] && win.rows[win.index].danger ? Theme.bad : Theme.accent
                }
            }
            delegate: ResultItem {
                required property var modelData
                required property int index
                width: list.width
                item: modelData
                selected: index === win.index
                onActivated: win.activate(modelData, false)
                onHoveredIn: (sx, sy) => {
                    const moved = win.lastMouseX >= 0 && (Math.abs(sx - win.lastMouseX) > 1 || Math.abs(sy - win.lastMouseY) > 1)
                    win.lastMouseX = sx; win.lastMouseY = sy
                    if (moved && modelData.selectable) win.index = index
                }
            }
            Text {
                visible: win.rows.length === 0
                anchors.centerIn: parent
                text: "Nothing found"
                color: Theme.textMuted
                font.family: Theme.font; font.pixelSize: Theme.fontSize
            }
        }
    }
}
