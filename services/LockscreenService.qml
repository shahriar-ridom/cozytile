pragma Singleton
import QtQuick
import Quickshell
import "../config"

// Lock screen options live in Settings.lockscreen. Every change re-renders hyprlock.conf
// (dotfiles/render.py reads the same settings file), debounced so sliders do not spam it.
Singleton {
    id: root

    readonly property var defaults: ({ wallpaper: "", blur: 3, dim: 70, clock: "large", font: "sans", hour24: true,
        seconds: false, showDate: true, showStatus: true, showUser: true, showAvatar: true, hint: "Enter password" })

    function get(k) { const c = Settings.lockscreen || {}; return c[k] !== undefined ? c[k] : defaults[k]; }
    function set(k, v) {
        const c = Object.assign({}, defaults, Settings.lockscreen || {});
        c[k] = v;
        Settings.lockscreen = c;
        Settings.save();
        render.restart();
    }
    function reset() { Settings.lockscreen = Object.assign({}, defaults); Settings.save(); render.restart(); }

    // image shown behind the lock screen: its own pick, else the desktop wallpaper
    function wallpaper() {
        const own = get("wallpaper");
        if (own) return own;
        const mon = UiState.focusedScreen ? UiState.focusedScreen.name : "";
        return WallpaperService.current(mon);
    }

    function preview() { UiState.settings = false; Quickshell.execDetached([Quickshell.shellPath("dotfiles/hypr/scripts/lock.sh")]); }

    Timer {
        id: render
        interval: 350
        onTriggered: Quickshell.execDetached([Quickshell.shellPath("dotfiles/theme-apply.sh"), Theme.name, "--dotfiles-only", "--no-reload"])
    }
}
