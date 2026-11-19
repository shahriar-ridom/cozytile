import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "../../services"

// The contents of one stack as plain objects: { name, path, url, dir, size, modified, suffix }. A directory is
// watched live; "recent" is the freedesktop recently-used list (re-read every 30 s and on refresh()).
// Only the first `limit` entries are read, so huge folders stay cheap.
Item {
    id: root

    property string path: ""            // an absolute directory, or "recent"
    property string sort: "modified"       // modified (newest first) | name | kind
    property int limit: 150
    readonly property bool recent: path === "recent"
    property var entries: []
    readonly property var newest: entries.length ? entries[0] : null

    function refresh() { if (recent) proc.running = true; }
    function urlOf(p) { return FolderService.url(p); }
    onPathChanged: { entries = []; refresh(); }
    onSortChanged: entries = []
    Component.onCompleted: refresh()

    // ---- directories: `path`, plus the `more` ones merged in (the Trash spans several drives) ----
    property var more: []
    readonly property var dirs: path === "" || recent ? [] : [path].concat(more)
    Timer { id: rebuild; interval: 60; onTriggered: root.read() }
    function read() {
        if (recent) return;
        let out = [];
        for (let k = 0; k < models.count; ++k) {
            const m = models.objectAt(k);
            if (!m || m.status !== FolderListModel.Ready) continue;
            const n = Math.min(m.count, limit);
            for (let i = 0; i < n; ++i)
                out.push({ name: m.get(i, "fileName"), path: m.get(i, "filePath"), url: m.get(i, "fileUrl").toString(), dir: m.get(i, "fileIsDir"),
                           size: m.get(i, "fileSize"), modified: m.get(i, "fileModified"), suffix: m.get(i, "fileSuffix").toLowerCase() });
        }
        if (models.count > 1) {
            const by = sort === "name" ? (a, b) => a.name.localeCompare(b.name) : sort === "kind" ? (a, b) => a.suffix.localeCompare(b.suffix) : (a, b) => b.modified - a.modified;
            out.sort((a, b) => sort !== "modified" && a.dir !== b.dir ? (a.dir ? -1 : 1) : by(a, b));
            out = out.slice(0, limit);
        }
        entries = out;
    }
    Instantiator {
        id: models
        model: root.dirs
        onObjectAdded: rebuild.restart()
        onObjectRemoved: rebuild.restart()
        delegate: FolderListModel {
            required property string modelData
            folder: root.urlOf(modelData)
            sortField: root.sort === "name" ? FolderListModel.Name : root.sort === "kind" ? FolderListModel.Type : FolderListModel.Time
            sortReversed: false
            showDirsFirst: root.sort !== "modified"
            showDotAndDotDot: false
            showHidden: false
            onStatusChanged: rebuild.restart()
            onCountChanged: rebuild.restart()
            onSortFieldChanged: rebuild.restart()
            onModelReset: rebuild.restart()
            onRowsInserted: rebuild.restart()
            onRowsRemoved: rebuild.restart()
            onDataChanged: rebuild.restart()
            onLayoutChanged: rebuild.restart()
        }
    }

    // ---- recent files ----
    Process {
        id: proc
        command: [Quickshell.shellPath("scripts/recent-files.py"), String(root.limit)]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.entries = JSON.parse(text).map(f => ({ name: f.name, path: f.path, url: root.urlOf(f.path), dir: false, size: 0,
                        modified: null, suffix: f.name.indexOf(".") > 0 ? f.name.split(".").pop().toLowerCase() : "" }));
                } catch (e) { root.entries = []; }
            }
        }
    }
    Timer { interval: 30000; repeat: true; running: root.recent; onTriggered: root.refresh() }
}
