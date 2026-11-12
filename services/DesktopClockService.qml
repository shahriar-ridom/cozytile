pragma Singleton
import QtQuick
import Quickshell
import "../config"

// Desktop clock options live in Settings.desktopClock.
// style: minimal | stacked | analog; position: custom | center | top-left | top-right | bottom-left | bottom-right;
// size: small | medium | large; font: family name, "" = system UI font
Singleton {
    id: root

    readonly property var defaults: ({ enabled: true, style: "minimal", position: "center", size: "medium",
        hour24: false, seconds: false, showDate: true, font: "", fx: 0.5, fy: 0.5 })
    // typeface of the clock; "" follows the system UI font
    readonly property string family: get("font") || Theme.font

    function get(k) { const c = Settings.desktopClock || {}; return c[k] !== undefined ? c[k] : defaults[k]; }
    function set(k, v) {
        const c = Object.assign({}, defaults, Settings.desktopClock || {});
        c[k] = v;
        Settings.desktopClock = c;
        Settings.save();
    }
    // move mode: the clock floats above windows and can be dragged (see DesktopClock.qml)
    property bool editing: false
    function setMany(o) {
        const c = Object.assign({}, defaults, Settings.desktopClock || {}, o);
        Settings.desktopClock = c;
        Settings.save();
    }
    function toggle() { set("enabled", !get("enabled")); }
    function reset() { Settings.desktopClock = Object.assign({}, defaults); Settings.save(); }
}
