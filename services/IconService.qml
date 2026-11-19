pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Icon packs, system-wide, through scripts/icon-theme.sh: GTK (gsettings + settings.ini), Qt (qt6ct) and the shell.
// The system settings are the source of truth, so nothing is persisted here. Qt keeps icons it already drew cached for
// the life of the process (a config reload keeps them too), so applying a pack restarts the shell.
Singleton {
    id: root

    property var packs: []          // [{ id, name, user, preview: [paths] }]
    property string current: ""
    property bool busy: false
    property string status: ""      // last result, shown under the install field
    property bool failed: false

    readonly property string script: Quickshell.shellPath("scripts/icon-theme.sh")

    function refresh() { lister.running = true; }
    function apply(id) { run(["apply", id], "Using " + id); }
    function install(src) { if (src.trim()) run(["install", src.trim()], ""); }
    function remove(id) { run(["remove", id], "Removed " + id); }

    property string okText: ""
    function run(args, ok) {
        if (busy) return;
        busy = true; okText = ok; status = args[0] === "install" ? "Installing…" : ""; failed = false;
        action.command = [script].concat(args);
        action.running = true;
    }

    Process {
        id: action
        stdout: StdioCollector { id: out }
        stderr: StdioCollector { id: err }
        onExited: code => {
            if (code === 0 && action.command[1] === "apply") { root.restartShell(); return; }
            root.busy = false;
            root.failed = code !== 0;
            root.status = code !== 0 ? (err.text.trim() || "Failed")
                : root.okText || ("Installed " + out.text.trim().split("\n").join(", "));
            root.refresh();
        }
    }
    function restartShell() {
        // `qs -p` from the repo has no installed copy to come back as: reload in place instead
        if (Quickshell.shellPath("").indexOf("/quickshell/cozytile") < 0) { Quickshell.reload(true); return; }
        Quickshell.execDetached(["sh", "-c", "sleep 0.3; qs kill -c cozytile; exec \"$0\"", Quickshell.shellPath("scripts/launch.sh")]);
    }
    Process {
        id: lister
        command: ["sh", "-c", "\"$0\" current; \"$0\" list", root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                root.current = lines.shift() || "";
                root.packs = lines.filter(l => l).map(l => JSON.parse(l));
            }
        }
    }
    Component.onCompleted: refresh()
}
