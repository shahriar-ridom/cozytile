import QtQuick
import Quickshell.Io

// Run-latest-wins async command. request() while busy queues only the newest; stale answers are tagged by key.
Item {
    id: r
    property string activeKey: ""
    property string pendingKey: ""
    property var pendingCmd: null
    readonly property bool busy: proc.running
    signal result(string key, string text)

    function request(key, cmd) { pendingKey = key; pendingCmd = cmd; if (!proc.running) _start(); }
    function cancel() { pendingCmd = null; pendingKey = ""; }
    function _start() {
        if (!pendingCmd) return;
        activeKey = pendingKey;
        proc.command = pendingCmd;
        pendingCmd = null;
        proc.running = true;
    }
    Process {
        id: proc
        stdout: StdioCollector { onStreamFinished: r.result(r.activeKey, text) }
        onRunningChanged: if (!running) r._start()
    }
}
