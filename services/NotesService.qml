pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The dock's scratch note: one plain-text file, saved shortly after every edit.
Singleton {
    id: root

    property string text: ""
    function edit(t) { if (t === text) return; text = t; save.restart(); }

    FileView {
        id: store
        path: Quickshell.env("HOME") + "/.local/state/cozytile/notes.txt"
        blockLoading: true
        printErrors: false
    }
    Timer { id: save; interval: 500; onTriggered: store.setText(root.text) }
    Component.onCompleted: root.text = store.text()
}
