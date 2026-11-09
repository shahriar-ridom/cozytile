pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Which overlay panels are open + which screen they belong to (the focused one).
Singleton {
    id: root
    property bool launcher: false
    property string launcherQuery: ""     // pre-fill for the next launcher open
    property bool power: false
    property bool wallpaper: false
    property bool audioPicker: false
    property string islandOpenOn: ""      // name of the screen whose island is expanded

    readonly property var focusedScreen: {
        const m = Hyprland.focusedMonitor;
        const s = m ? Quickshell.screens.find(x => x.name === m.name) : null;
        return s ?? Quickshell.screens[0] ?? null;
    }

    // OSD request: kind = volume | mic | brightness | kbd
    signal osd(string kind, real value, bool muted)

    function toggleIsland() {
        const n = focusedScreen ? focusedScreen.name : "";
        const was = islandOpenOn === n;
        closeAll();
        islandOpenOn = was ? "" : n;
    }
    function closeAll() { islandOpenOn = ""; launcher = false; power = false; wallpaper = false; audioPicker = false; }
    // Opening one overlay closes the others.
    function toggle(which) {
        const was = root[which];
        closeAll();
        root[which] = !was;
    }
}
