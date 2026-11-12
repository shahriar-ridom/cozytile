import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../config"
import "../../services"
import "../../components"
import "../launcher"
import "../launcher/Search.js" as S

// Menu-bar search, macOS style: a small field that drops out of the bar directly beneath the
// "Search" cap and grows a result list as you type (apps, open windows, calculator, files, web).
// The big launcher keeps the long tail: actions, emoji, clipboard, shell prompt.
//   Keys: Up/Down, Ctrl+J/K, Tab move   Enter open   Ctrl+Enter open in launcher   Esc close
PanelWindow {
    id: win
    screen: UiState.focusedScreen
    visible: UiState.search || card.opacity > 0.01
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "cozytile-search"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: UiState.search ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property string home: Quickshell.env("HOME")
    readonly property int maxListH: 300
    readonly property int fieldH: 36
    property string query: ""
    property int index: 0
    property string selKey: ""
    property real lastMouseX: -1
    property real lastMouseY: -1
    property var fileHits: []
    property var hist: ({})

    // false at creation, then follows the open state, so the open animation still plays
    property bool shown: false
    Component.onCompleted: {
        try { const h = JSON.parse(histFile.text()); if (h && typeof h === "object") hist = h; } catch (e) {}
        shown = Qt.binding(() => UiState.search);
        if (UiState.search) opened();
    }
    // keeps the window (and its LazyLoader in shell.qml) alive until the fade-out is done
    readonly property bool busy: visible

    // app usage is shared with the launcher (read only here)
    FileView {
        id: histFile
        path: win.home + "/.local/state/cozytile/launcher-history.json"
        blockLoading: true
        printErrors: false
    }

    function opened() {
        selKey = ""; query = ""; fileHits = [];
        input.text = ""; input.forceActiveFocus();
        Hyprland.refreshToplevels();
    }
    Connections { target: UiState; function onSearchChanged() { if (UiState.search) win.opened(); } }
    function close() { UiState.search = false; }

    // ---- results ----------------------------------------------------------
    function row(kind, key, title, extra) {
        return Object.assign({ kind: kind, key: key, title: title, selectable: true, h: 44, hint: "Open" }, extra || {});
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
    function build() {
        const raw = query.trim();
        const q = raw.toLowerCase();
        if (raw === "") return { rows: [], height: 0 };
        const sections = [];
        function add(title, rows) { if (rows.length) sections.push({ title: title, rows: rows }); }

        // calculator
        let calc = null;
        if (S.mathy(raw)) {
            const expr = raw.replace(/^=\s*/, "");
            const v = S.safeEval(expr);
            if (v !== null && (/[^\d.\s]/.test(expr.replace(/^[-+]/, "")) || raw[0] === "="))
                calc = row("calc", "calc", S.fmtNumber(v), { subtitle: expr, glyph: "", copy: String(Number(v.toPrecision(12))), h: 64, hint: "Copy" });
        }
        if (calc) add("Calculator", [calc]);

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
        const apps = DesktopEntries.applications.values.filter(e => !e.noDisplay)
            .map(e => ({ e: e, s: appScore(e) })).filter(x => x.s > 0)
            .sort((a, b) => b.s - a.s || a.e.name.localeCompare(b.e.name)).slice(0, 5)
            .map(x => row("app", "app:" + x.e.id, x.e.name, { subtitle: x.e.comment || x.e.genericName || "", icon: x.e.icon, entry: x.e }));
        add("Applications", apps);

        add("Windows", windows().filter(w => S.score(w.title, q) > 0 || S.score(w.cls, q) > 0).slice(0, 3).map(w => {
            const de = w.cls ? DesktopEntries.heuristicLookup(w.cls) : null;
            return row("window", "win:" + w.address, w.title, {
                subtitle: (w.cls || "Window") + (w.ws ? ", workspace " + w.ws : ""), alwaysSub: true,
                icon: de ? de.icon : w.cls.toLowerCase(), addr: w.address, hint: "Switch to" });
        }));

        if (q.length >= 2 && !calc) {
            const words = q.split(/\s+/).filter(w => w);
            const hits = fileHits.filter(f => { const p = f.path.toLowerCase(); return words.every(w => p.includes(w)); });
            add("Files", hits.map(f => ({ f: f, s: S.score(S.basename(f.path), q) + (f.isDir ? 3 : 0) - f.path.split("/").length * 0.6 }))
                .sort((a, b) => b.s - a.s || a.f.path.length - b.f.path.length).slice(0, 4)
                .map(x => row("file", "file:" + x.f.path, S.basename(x.f.path), {
                    subtitle: S.shortPath(S.dirname(x.f.path), win.home), alwaysSub: true, path: x.f.path,
                    glyph: x.f.isDir ? "" : "" })));
        }

        const b = S.bang(raw);
        const url = S.asUrl(raw);
        if (b) add("Web", [row("web", "web", "Search " + b.engine.name + " for “" + b.term + "”", { glyph: "", url: S.searchUrl(b.engine, b.term) })]);
        else if (url) add("Web", [row("web", "web", "Open " + url.replace(/^https?:\/\//, ""), { glyph: "", url: url })]);
        else if (!calc) add("Web", [row("web", "web", "Search the web for “" + raw + "”", { glyph: "", url: S.searchUrl(S.defaultEngine(), raw) })]);

        const rows = [];
        let height = 0;
        for (const s of sections) {
            if (sections.length > 1) { rows.push({ kind: "header", key: "h:" + s.title, title: s.title, h: 28, selectable: false }); height += 28; }
            for (const r of s.rows) { rows.push(r); height += r.h; }
        }
        return { rows: rows, height: height };
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

    function record(key) {
        const h = hist[key] || { n: 0, t: 0 };
        const next = Object.assign({}, hist);
        next[key] = { n: h.n + 1, t: Date.now() };
        hist = next;
        histFile.setText(JSON.stringify(hist));
    }
    function activate(r, secondary) {
        if (!r || !r.selectable) return;
        close();
        switch (r.kind) {
        case "app": record(r.key); r.entry.execute(); break;
        case "window": {
            const a = r.addr.startsWith("0x") ? r.addr : "0x" + r.addr;
            Hyprland.dispatch(Hyprland.usingLua ? "hl.dsp.focus({ window = \"address:" + a + "\" })" : "focuswindow address:" + a);
            break; }
        case "file": Quickshell.execDetached(["xdg-open", secondary ? S.dirname(r.path) : r.path]); break;
        case "calc": Quickshell.execDetached(["wl-copy", r.copy]); break;
        case "web": Quickshell.execDetached(["xdg-open", r.url]); break;
        }
    }
    function openInLauncher() { const t = query; UiState.closeAll(); UiState.launcherQuery = t; UiState.launcher = true; }

    Runner {
        id: fileRunner
        onResult: (key, text) => {
            const hits = [];
            for (const p of text.split("\n")) {
                if (!p) continue;
                const isDir = p.endsWith("/");
                hits.push({ path: isDir ? p.slice(0, -1) : p, isDir: isDir });
            }
            win.fileHits = hits;
        }
    }
    Timer {
        id: debounce
        interval: 160
        onTriggered: {
            const raw = win.query.trim();
            if (raw.length < 2 || S.mathy(raw)) { fileRunner.cancel(); win.fileHits = []; return; }
            fileRunner.request(raw.toLowerCase(), ["timeout", "2", "fd", "-i", "-a", "--max-results", "60", "--type", "f", "--type", "d",
                "-E", "node_modules", "-E", ".git", "-E", ".cache", "-E", "target", "-E", "__pycache__", "-E", "*cache*", "-E", "*Cache*",
                S.regexFromQuery(raw), win.home]);
        }
    }

    // ---- view ---------------------------------------------------------------
    // invisible: click outside closes, nothing is dimmed
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: win.close() }

    // sibling of the card: inside it the card's clip would cut the shadow off
    Shadowed { target: card; z: 0; radius: Theme.radius + 2; opacity: card.opacity; scale: card.scale; transformOrigin: Item.Top }

    Rectangle {
        id: card
        z: 1
        readonly property int listH: win.built.height > 0 ? Math.min(win.maxListH, win.built.height) + 14 : 0
        width: Math.min(320, parent.width - 16)
        height: win.fieldH + listH + (listH > 0 ? 1 : 0)
        x: Math.max(8, Math.min(parent.width - width - 8, UiState.searchX))
        y: Theme.barMarginTop + Theme.barHeight - 1       // hangs flush from the bar, same tone
        topLeftRadius: 0; topRightRadius: 0
        bottomLeftRadius: Theme.radius + 2; bottomRightRadius: Theme.radius + 2
        color: Theme.barCapFill
        clip: true
        opacity: win.shown ? 1 : 0
        transformOrigin: Item.Top
        scale: win.shown ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent }          // swallow clicks


        Item {
            id: field
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: win.fieldH
            Glyph {
                x: 14; anchors.verticalCenter: parent.verticalCenter
                text: ""; size: 12
                color: input.text.length ? Theme.accent : Theme.textMuted
                Behavior on color { ColorAnimation { duration: Theme.animNormal } }
            }
            TextInput {
                id: input
                anchors { left: parent.left; right: parent.right; leftMargin: 36; rightMargin: 14; verticalCenter: parent.verticalCenter }
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.barCap
                font.family: Theme.font; font.pixelSize: 14
                clip: true
                onTextChanged: { win.selKey = ""; win.query = text; debounce.restart(); }
                Keys.onEscapePressed: win.close()
                Keys.onDownPressed: win.move(1)
                Keys.onUpPressed: win.move(-1)
                Keys.onTabPressed: win.move(1)
                Keys.onBacktabPressed: win.move(-1)
                Keys.onPressed: e => {
                    if (e.modifiers & Qt.ControlModifier) {
                        if (e.key === Qt.Key_J || e.key === Qt.Key_N) { win.move(1); e.accepted = true; }
                        else if (e.key === Qt.Key_K || e.key === Qt.Key_P) { win.move(-1); e.accepted = true; }
                    }
                }
                Keys.onReturnPressed: e => e.modifiers & Qt.ControlModifier ? win.openInLauncher() : win.activate(win.rows[win.index], !!(e.modifiers & Qt.ShiftModifier))
                Keys.onEnterPressed: e => e.modifiers & Qt.ControlModifier ? win.openInLauncher() : win.activate(win.rows[win.index], !!(e.modifiers & Qt.ShiftModifier))
                Text {
                    visible: !input.text && !input.preeditText
                    text: "Search"
                    color: Theme.textMuted
                    font: input.font
                }
            }
        }

        Rectangle {
            id: divider
            visible: card.listH > 0
            anchors { top: field.bottom; left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10 }
            height: 1
            color: Theme.slash
        }

        ListView {
            id: list
            visible: card.listH > 0
            anchors { top: divider.bottom; left: parent.left; right: parent.right; margins: 4; topMargin: 4 }
            height: card.listH - 14
            clip: true
            model: win.rows
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: win.index
            highlightMoveDuration: 120
            highlightMoveVelocity: -1
            highlight: Item {
                width: list.width
                height: list.currentItem ? list.currentItem.height : 44
                visible: list.currentItem && !list.currentItem.header
                Rectangle { anchors.fill: parent; radius: Theme.radius; color: Theme.surfaceHigh }
                Rectangle { x: 5; width: 3; height: 16; radius: 2; anchors.verticalCenter: parent.verticalCenter; color: Theme.accent }
            }
            delegate: ResultItem {
                required property var modelData
                required property int index
                width: list.width
                item: modelData
                selected: index === win.index
                onActivated: win.activate(modelData, false)
                onHoveredIn: (sx, sy) => {
                    const moved = win.lastMouseX >= 0 && (Math.abs(sx - win.lastMouseX) > 1 || Math.abs(sy - win.lastMouseY) > 1);
                    win.lastMouseX = sx; win.lastMouseY = sy;
                    if (moved && modelData.selectable) win.index = index;
                }
            }
        }
    }
}
