pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Dispatch helpers that work with both classic (hyprlang) and Lua-configured Hyprland.
// Lua-mode rejects "workspace 3" ("')' expected near '3'"), so build real hl.dsp.* expressions.
Singleton {
    id: root

    function _run(lua, classic) { Hyprland.dispatch(Hyprland.usingLua ? lua : classic); }

    function focusWorkspace(id) { _run("hl.dsp.focus({ workspace = " + Number(id) + " })", "workspace " + Number(id)); }
    // delta > 0 next, < 0 previous (among existing workspaces)
    function stepWorkspace(delta) {
        const t = delta > 0 ? "e+1" : "e-1";
        _run("hl.dsp.focus({ workspace = \"" + t + "\" })", "workspace " + t);
    }
    function toggleSpecial(name) { _run("hl.dsp.workspace.toggle_special(\"" + name + "\")", "togglespecialworkspace " + name); }
}
