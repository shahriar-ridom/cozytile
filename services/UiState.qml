pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Which overlay panels are open + which screen they belong to (the focused one).
Singleton {
    id: root
    property bool launcher: false
    property string launcherQuery: ""     // pre-fill for the next launcher open
    property bool search: false           // bar search dropdown (anchored under the Search cap)
    property real searchX: 0              // left edge of the Search cap, screen px
    property bool power: false
    property bool wallpaper: false
    property string wallpaperFor: ""     // "" = desktop wallpaper, "lock" = pick the lock screen image
    property bool audioPicker: false
    property bool settings: false
    property string settingsPage: ""      // requested settings page (by name); the panel clears it
    property int settingsPageIndex: 0     // last shown settings page (the panel is recreated on each open)
    // stat popup under the bar: "" | cpu | ram | temp, anchored at popupX (centre, screen px)
    property string statPopup: ""
    property real statPopupX: 0
    // global menu dropdown: index of the open top-level menu (-1 = closed), anchored at its left edge (screen px)
    // -2 = the » dropdown listing the titles from globalMenuFrom on
    property int globalMenuIndex: -1
    property int globalMenuFrom: 0
    readonly property bool globalMenuOpen: globalMenuIndex !== -1
    property real globalMenuX: 0
    // logo dropdown under the bar's logo, anchored at its left edge (screen px)
    property bool logoMenu: false
    property real logoMenuX: 0
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
    function closeAll() { islandOpenOn = ""; launcher = false; search = false; power = false; wallpaper = false; wallpaperFor = ""; audioPicker = false; settings = false; statPopup = ""; globalMenuIndex = -1; logoMenu = false; }
    function toggleLogoMenu(x) {
        const was = logoMenu;
        closeAll();
        if (!was) { logoMenuX = x; logoMenu = true; }
    }
    // open the dropdown under the bar's Search cap; x = cap's left edge in screen px
    function toggleSearch(x) {
        const was = search;
        closeAll();
        if (!was) { searchX = x; search = true; }
    }
    function toggleStat(kind, x) {
        const was = statPopup === kind;
        closeAll();
        if (!was) { statPopupX = x; statPopup = kind; }
    }
    // open the wallpaper picker for the desktop ("") or the lock screen ("lock")
    function pickWallpaper(forWhat) { closeAll(); wallpaperFor = forWhat; wallpaper = true; }
    // Opening one overlay closes the others.
    function toggle(which) {
        const was = root[which];
        closeAll();
        root[which] = !was;
    }
}
