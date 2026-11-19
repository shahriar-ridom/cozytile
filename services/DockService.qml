pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import QtQml
import Qt.labs.folderlistmodel
import "../config"

// Dock contents: pinned apps (Settings.dockPinned = desktop-entry ids) in their saved order, running or not, then
// running apps that aren't pinned (Settings.dockShowRunning), then the folder stacks (Settings.dockStacks). One item
// per app; its windows come from WindowService.
// Item: { key, id, name, icon, entry, pinned, windows, focused, urgent }, a stack also has { stack: true, path, dir, view, sort }
Singleton {
    id: root

    readonly property var items: {
        DesktopEntries.applications.values.length;      // re-resolve once the application list has loaded
        if (gaming) return gameItems();
        const groups = WindowService.groups;
        const out = [];
        const make = (key, id, name, icon, e, pinned, ws) => ({
            key: key, id: id, name: name, icon: icon, entry: e, pinned: pinned, windows: ws,
            focused: ws.some(w => w.activated), urgent: ws.some(w => w.urgent)
        });
        for (const id of Settings.dockPinned) {
            const e = DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id);
            if (!e || out.some(o => o.entry === e)) continue;
            const g = groups.find(x => x.key === e.id);
            out.push(make(e.id, id, e.name, e.icon, e, true, g ? g.windows : []));
        }
        if (Settings.dockShowRunning)
            for (const g of groups) {
                if (out.some(o => o.key === g.key)) continue;
                const e = g.entry;
                out.push(make(g.key, e ? e.id : g.cls, e ? e.name : g.cls, e ? e.icon : g.cls.toLowerCase(), e, false, g.windows));
            }
        for (const st of Settings.dockStacks) {
            if (!st || !st.path) continue;
            const dir = st.path === "recent" ? "recent" : FolderService.expand(st.path);
            out.push({ key: "stack:" + st.path, id: st.path, name: st.name, icon: stackIcon(dir), entry: null, pinned: false, windows: [],
                       focused: false, urgent: false, stack: true, path: st.path, dir: dir, view: st.view ?? "fan", sort: st.sort ?? "modified" });
        }
        for (const id of Settings.dockTools) {
            const it = toolItem(id);
            if (it) out.push(it);
        }
        if (Settings.dockTrash)
            out.push({ key: "stack:trash", id: "trash", name: "Trash", icon: pick([trashCount > 0 ? "user-trash-full" : "user-trash", "user-trash"], "folder"),
                       entry: null, pinned: false, windows: [], focused: false, urgent: false, stack: true, trash: true, path: "trash",
                       dir: trashDir, more: trashDirs.slice(1), view: "grid", sort: "modified" });
        return out;
    }

    // ---- context awareness ----
    // modeOverride: "" detects the mode; "normal" turns every context behaviour off, "hidden" keeps the dock away, "gaming" forces the minimal dock.
    // Per screen, the dock hides for a fullscreen window itself (Dock.qml); this is the part that changes what the dock holds.
    property string modeOverride: ""
    readonly property bool auto: Settings.dockContext && modeOverride === ""
    readonly property bool gaming: modeOverride === "gaming" || (auto && Quickshell.screens.some(s => WindowService.fullscreenOn(s, true)))
    readonly property string mode: modeOverride !== "" ? modeOverride : gaming ? "gaming" : "normal"
    // keyboard: activate the nth app of the dock (1-based, pinned and running, in order)
    function activateNth(n) {
        const apps = items.filter(i => i.entry || i.windows.length);
        if (n >= 1 && n <= apps.length) activate(apps[n - 1]);
    }
    function toggleGaming() { modeOverride = modeOverride === "gaming" ? "" : "gaming"; }
    // the minimal dock: screenshot, screen recording and system stats, whatever the tools setting says
    function gameItems() { return ["screenshot", "record", "system"].map(toolItem); }

    // ---- quick tools ----
    function toolItem(id) {
        const t = tools[id];
        return t ? { key: "tool:" + id, id: id, name: t.name, icon: pick(id === "record" && recording ? ["media-record"] : t.icons, "application-x-executable"), entry: null,
                     pinned: false, windows: [], focused: false, urgent: false, tool: true } : null;
    }
    // screen recording (an `action` tool has no panel; opening it toggles). Ctrl+C-style SIGINT lets the recorder finish the file.
    property string recordFile: ""
    readonly property bool recording: recorder.running
    function toggleRecord() {
        if (recording) { Quickshell.execDetached(["pkill", "-INT", "-x", "gpu-screen-recorder"]); return; }
        recordFile = (Quickshell.env("XDG_VIDEOS_DIR") || Quickshell.env("HOME") + "/Videos") + "/Recordings/Recording_" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".mp4";
        recorder.running = true;
    }
    Process {
        id: recorder
        command: ["sh", "-c", 'command -v gpu-screen-recorder >/dev/null || { notify-send -a Recorder "Screen recording needs gpu-screen-recorder"; exit 1; }; '
            + 'mkdir -p "$(dirname "$1")"; exec gpu-screen-recorder -w screen -f 60 -o "$1"', "sh", root.recordFile]
        onExited: (code, status) => { if (code === 0 || code === 130) Quickshell.execDetached(["notify-send", "-a", "Recorder", "Recording saved", root.recordFile]); }
    }
    readonly property var tools: ({
        clipboard: { name: "Clipboard", icons: ["edit-paste", "edit-copy", "klipper"] },
        screenshot: { name: "Screenshot", icons: ["applets-screenshooter", "spectacle", "camera-photo"] },
        notes: { name: "Quick Notes", icons: ["accessories-notes", "knotes", "text-editor"] },
        system: { name: "System Monitor", icons: ["utilities-system-monitor", "preferences-system-performance"] },
        record: { name: "Screen Recording", icons: ["media-record", "camera-video", "video-display"], action: true }
    })
    function removeTool(id) { Settings.dockTools = Settings.dockTools.filter(t => t !== id); }
    function pick(names, fallback) { return names.find(n => Quickshell.iconPath(n, true)) ?? fallback; }
    // asks the dock on the focused screen to open a tool's panel (IPC, keybinds); the serial lets the same tool be asked twice
    property var toolRequest: ({ id: "", serial: 0 })
    function openTool(id) {
        if (tools[id] && tools[id].action) { toggleRecord(); return; }
        toolRequest = { id: id, serial: toolRequest.serial + 1 };
    }

    // ---- the Trash: the freedesktop trash that Luma Files uses, so both always agree ----
    readonly property string trashDir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/Trash/files"
    // plus the trash of every mounted drive that has one ($top/.Trash/$uid or $top/.Trash-$uid), as Luma lists them
    property var trashDirs: [trashDir]
    property int trashCount: 0
    function recount() {
        let n = 0;
        for (let i = 0; i < trashModels.count; ++i) n += trashModels.objectAt(i).count;
        trashCount = n;
    }
    Instantiator {
        id: trashModels
        model: root.trashDirs
        onObjectAdded: root.recount()
        onObjectRemoved: root.recount()
        delegate: FolderListModel {
            required property string modelData
            folder: FolderService.url(modelData)
            showHidden: true; showDotAndDotDot: false
            onCountChanged: root.recount()
        }
    }
    function scanTrash() { if (!volumes.running) volumes.running = true; }
    Process {
        id: volumes
        command: ["sh", "-c", 'uid=$(id -u); awk \'$1 ~ /^\\// {print $2}\' /proc/mounts | sort -u | while read -r m; do m=$(printf "%b" "$m"); '
            + 'for d in "$m/.Trash/$uid/files" "$m/.Trash-$uid/files"; do [ -d "$d" ] && echo "$d"; done; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.split("\n").filter(l => l && l !== root.trashDir).sort();
                const next = [root.trashDir].concat(found);
                if (next.join("\n") !== root.trashDirs.join("\n")) root.trashDirs = next;
            }
        }
    }
    Timer { interval: 30000; repeat: true; running: Settings.dockTrash; triggeredOnStart: true; onTriggered: root.scanTrash() }
    function trashUrls(urls) {
        const p = urls.map(u => u.toString()).filter(u => u.startsWith("file://"));
        if (p.length) { Quickshell.execDetached(["gio", "trash", "--"].concat(p)); rescan.restart(); }
    }
    Timer { id: rescan; interval: 1500; onTriggered: root.scanTrash() }   // a drive's first trashed file creates its trash
    // gio's own "--empty" needs gvfs's trash:/// backend, which is often missing, so, like Luma Files, delete what the trash
    // folders hold: files/*, info/*, and the directorysizes cache. Only folders that look like a trash's files dir are touched.
    readonly property string emptyScript: 'for d; do case "$d" in */Trash/files|*/.Trash/*/files|*/.Trash-*/files) ;; *) continue ;; esac; p=$(dirname "$d"); '
        + 'find "$d" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +; [ -d "$p/info" ] && find "$p/info" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +; rm -f "$p/directorysizes"; done'
    function emptyTrash() { Quickshell.execDetached(["sh", "-c", emptyScript, "sh"].concat(trashDirs)); }

    // ---- folder stacks ----
    readonly property var stackIcons: ({ Downloads: "folder-download", Documents: "folder-documents", Pictures: "folder-pictures",
                                         Music: "folder-music", Videos: "folder-videos" })
    function stackIcon(dir) {
        const n = dir === "recent" ? "folder-recent" : stackIcons[dir.split("/").pop()] ?? "folder";
        return Quickshell.iconPath(n, true) ? n : "folder";
    }
    function setStack(path, patch) { Settings.dockStacks = Settings.dockStacks.map(s => s.path === path ? Object.assign({}, s, patch) : s); }
    function removeStack(path) { Settings.dockStacks = Settings.dockStacks.filter(s => s.path !== path); }
    function addStack(path) {
        path = path === "recent" ? path : path.replace(/\/+$/, "") || "/";
        if (Settings.dockStacks.some(s => s.path === path)) return;
        Settings.dockStacks = Settings.dockStacks.concat([{ name: path === "recent" ? "Recent" : path.split("/").pop() || "/", path: path, view: "fan", sort: "modified" }]);
    }
    // dropped URLs: the directories among them become stacks
    function addFolders(urls) {
        const paths = urls.map(u => u.toString()).filter(u => u.startsWith("file://")).map(u => decodeURIComponent(u.slice(7)));
        if (!paths.length) return;
        dirs.command = ["sh", "-c", 'for p; do [ -d "$p" ] && printf "%s\\n" "$p"; done', "sh"].concat(paths);
        dirs.running = true;
    }
    Process {
        id: dirs
        stdout: StdioCollector { onStreamFinished: text.split("\n").filter(l => l).forEach(p => root.addStack(p)) }
    }

    // launch feedback: key -> start time, until the app's first window appears (or 10 s pass)
    property var launching: ({})
    function _drop(pred) {
        const next = {};
        let changed = false;
        for (const k in launching) { if (pred(k)) changed = true; else next[k] = launching[k]; }
        if (changed) launching = next;
    }
    onItemsChanged: _drop(k => items.some(i => i.key === k && i.windows.length > 0))
    Timer {
        interval: 1000; repeat: true
        running: Object.keys(root.launching).length > 0
        onTriggered: root._drop(k => Date.now() - root.launching[k] > 10000)
    }

    function launch(item) {
        if (!item.entry) return;
        if (!item.windows.length) { const l = Object.assign({}, launching); l[item.key] = Date.now(); launching = l; }
        item.entry.execute();
    }
    // not running: launch. One window: focus it. Several: cycle from the focused one (or start at the most recent).
    function activate(item) {
        const ws = item.windows;
        if (!ws.length) { launch(item); return; }
        const i = ws.findIndex(w => w.activated);
        if (i >= 0) { WindowService.focus(ws[(i + 1) % ws.length]); return; }
        const hist = w => (w.lastIpcObject && w.lastIpcObject.focusHistoryID !== undefined) ? w.lastIpcObject.focusHistoryID : 1e9;
        WindowService.focus(ws.slice().sort((a, b) => hist(a) - hist(b))[0]);
    }

    // put `item` at `at` among the shown pinned apps (pinning it if it isn't). It is inserted before the app that will
    // follow it, so saved ids that resolve to no installed app keep their places.
    function placePinned(item, at) {
        const id = item.pinned ? item.id : (item.entry ? item.entry.id : "");
        if (!id) return;
        const shown = items.filter(i => i.pinned && i.key !== item.key);
        const list = Settings.dockPinned.filter(p => p !== id);
        const next = shown[at], prev = shown[at - 1];
        let i = next ? list.indexOf(next.id) : prev ? list.indexOf(prev.id) + 1 : 0;
        list.splice(i < 0 ? list.length : i, 0, id);
        Settings.dockPinned = list;
    }
    // drops: an app whose Exec takes files or URLs (%f %F %u %U) gets them through `gio launch`, which expands the field
    // codes. A terminal without them opens in the dropped folder (or the dropped file's folder). Anything else refuses.
    function takesFiles(e) { return /%[fFuU]/.test(e.execString); }
    function isTerminal(e) { return Array.from(e.categories || []).indexOf("TerminalEmulator") >= 0; }
    function canOpen(item) { return !!item.entry && (takesFiles(item.entry) || isTerminal(item.entry)); }
    function openWith(item, urls) {
        if (!canOpen(item) || !urls.length) return false;
        const e = item.entry, list = urls.map(u => u.toString());
        if (!takesFiles(e)) {
            if (!list[0].startsWith("file://")) return false;
            const path = decodeURIComponent(list[0].slice(7));
            Quickshell.execDetached(["sh", "-c", 'if [ -d "$1" ]; then cd "$1"; else cd "$(dirname "$1")"; fi && shift && exec "$@"',
                "sh", path].concat(Array.from(e.command)));
        } else {
            const find = 'id=$1; shift; IFS=:; for d in "${XDG_DATA_HOME:-$HOME/.local/share}" ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do '
                + 'f="$d/applications/$id.desktop"; [ -f "$f" ] && exec gio launch "$f" "$@"; done';
            Quickshell.execDetached(["sh", "-c", find, "sh", e.id].concat(list));
        }
        if (!item.windows.length) { const l = Object.assign({}, launching); l[item.key] = Date.now(); launching = l; }
        return true;
    }

    function isPinned(item) { return Settings.dockPinned.indexOf(item.id) >= 0 || (item.entry && Settings.dockPinned.indexOf(item.entry.id) >= 0); }
    function pin(item) { if (item.entry && !isPinned(item)) Settings.dockPinned = Settings.dockPinned.concat([item.entry.id]); }
    function unpin(item) { Settings.dockPinned = Settings.dockPinned.filter(id => id !== item.id && !(item.entry && id === item.entry.id)); }
    function resetPinned() { Settings.dockPinned = ["kitty", "org.kde.dolphin", "librewolf", "zen", "firefox", "code", "discord", "spotify"]; }

    function toggle() { Settings.dockEnabled = !Settings.dockEnabled; }
}
