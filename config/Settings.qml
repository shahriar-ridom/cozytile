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
    property alias barStyle: adapter.barStyle
    property alias globalMenu: adapter.globalMenu
    property alias timerEnd: adapter.timerEnd
    property alias timerTotal: adapter.timerTotal
    property alias timerLabel: adapter.timerLabel
    property alias timerLast: adapter.timerLast
    property alias syncDotfiles: adapter.syncDotfiles
    property alias showTemp: adapter.showTemp
    property alias statsInterval: adapter.statsInterval
    property alias hypr: adapter.hypr
    property alias monitors: adapter.monitors
    property alias autostart: adapter.autostart
    property alias idle: adapter.idle
    property alias nightLight: adapter.nightLight
    property alias lockscreen: adapter.lockscreen
    readonly property bool loaded: store.loaded
    // true once the file was read, or found missing and defaults were written
    property bool ready: false

    function save() { store.writeAdapter(); }

    FileView {
        id: store
        path: root.file
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        // First run: file is missing, defaults from the adapter are used and written.
        onLoaded: root.ready = true
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter(); root.ready = true; }

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
            // bar look: "bar" (one full-width bar) or "islands" (three floating pills)
            property string barStyle: "bar"
            // active window title on the left of the bar (off: calmer bar, the island owns the centre)
            property bool showWindowTitle: false
            // macOS-style global menu: the focused app's menus (File, Edit, ...) on the left of the bar
            property bool globalMenu: true
            // running timer survives shell restarts (epoch ms; 0 = none)
            property real timerEnd: 0
            property int timerTotal: 0
            property string timerLabel: ""
            property int timerLast: 300
            // re-render generated dotfiles (kitty, starship, hyprlock, ...) whenever the theme changes
            property bool syncDotfiles: true
            // CPU/RAM/temperature sampling period (ms) and whether the bar shows temperature
            property int statsInterval: 2000
            property bool showTemp: true
            // Hyprland option overrides set from the settings app: { "general.gaps_in": 8, ... }
            property var hypr: ({})
            // per-output overrides: { "HDMI-A-1": { mode, scale, transform, position, vrr, disabled } }
            property var monitors: ({})
            // user autostart: [{ name, command, enabled }]
            property var autostart: []
            // hypridle timeouts in seconds (0 = never)
            property var idle: ({ lock: 300, dpms: 360, suspend: 1200 })
            // hyprsunset: warm colours (always or between start/end) and software dimming (gamma %)
            // lock screen (hyprlock) look, rendered by dotfiles/render.py. wallpaper "" = follow the desktop one;
            // clock: large|medium|small; font: sans|rounded|mono; blur 0-5 passes; dim = brightness %
            property var lockscreen: ({ wallpaper: "", blur: 3, dim: 70, clock: "large", font: "sans", hour24: true, seconds: false, showDate: true, showStatus: true, showUser: true, showAvatar: true, hint: "Enter password" })
            property var nightLight: ({ enabled: false, temperature: 4000, scheduled: false, start: "20:00", end: "07:00", gamma: 100 })
        }
    }
}
