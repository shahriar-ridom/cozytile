pragma Singleton
import QtQuick
import Quickshell
import "../config"

// Frosted glass switch. The shell reads Settings.frostedGlass through Theme (translucent, palette-tinted surfaces);
// this service carries the toggle to the rest of the desktop:
//  - Hyprland: every shell layer is blurred (config/rules.lua); windows get the frost block through HyprConfigService
//  - dotfiles: kitty, hyprlock, GTK, Qt and the SDDM theme are re-rendered (dotfiles/render.py reads "frostedGlass")
Singleton {
    id: root

    readonly property bool enabled: Settings.frostedGlass

    function set(on) { Settings.frostedGlass = !!on; }
    function toggle() { set(!Settings.frostedGlass); }

    Connections {
        target: Settings
        function onFrostedGlassChanged() { root.sync(); }
    }
    function sync() {
        HyprConfigService.applyFrost();
        // kitty's translucency is part of the rendered colours: re-render, then ask kitty to reload its config
        Quickshell.execDetached(["sh", "-c", "\"$1\" \"$2\" --dotfiles-only --no-reload; pkill -USR1 -x kitty",
                                 "sh", Quickshell.shellPath("dotfiles/theme-apply.sh"), Theme.name]);
    }
}
