pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Persisted user settings: ~/.local/state/cozytile/settings.json
Singleton {
    id: root

    readonly property string stateDir: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")
    readonly property string file: stateDir + "/cozytile/settings.json"

    property alias theme: adapter.theme
    property alias wallpaperDirs: adapter.wallpaperDirs
    property alias wallpapers: adapter.wallpapers
    property alias wallpaperTheming: adapter.wallpaperTheming
    property alias osdTimeout: adapter.osdTimeout
    property alias showWorkspaceNumbers: adapter.showWorkspaceNumbers
    property alias dnd: adapter.dnd
    property alias baseTheme: adapter.baseTheme
    property alias showWindowTitle: adapter.showWindowTitle
    property alias timerEnd: adapter.timerEnd
    property alias timerTotal: adapter.timerTotal
    property alias timerLabel: adapter.timerLabel
    property alias timerLast: adapter.timerLast
    property alias syncDotfiles: adapter.syncDotfiles
    readonly property bool loaded: store.loaded

    function save() { store.writeAdapter(); }

    FileView {
        id: store
        path: root.file
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        // First run: file is missing, defaults from the adapter are used and written.
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter(); }

        adapter: JsonAdapter {
            id: adapter
            property string theme: "everforest"
            property list<string> wallpaperDirs: ["~/Pictures/Wallpapers"]
            // per-monitor wallpapers: { "HDMI-A-1": "/path.jpg", "*": "/fallback.jpg" }
            property var wallpapers: ({})
            // last built-in theme (restored when wallpaper theming is turned off)
            property string baseTheme: "everforest"
            property bool wallpaperTheming: true
            property int osdTimeout: 1600
            property bool showWorkspaceNumbers: false
            property bool dnd: false
            // active window title on the left of the bar (off: calmer bar, the island owns the centre)
            property bool showWindowTitle: false
            // running timer survives shell restarts (epoch ms; 0 = none)
            property real timerEnd: 0
            property int timerTotal: 0
            property string timerLabel: ""
            property int timerLast: 300
            // re-render generated dotfiles (kitty, starship, hyprlock, ...) whenever the theme changes
            property bool syncDotfiles: true
        }
    }
}
