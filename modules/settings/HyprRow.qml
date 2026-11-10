import QtQuick
import "../../services"

// SettingRow bound to one Hyprland option: shows the "changed" dot and resets it.
SettingRow {
    property string key: ""
    readonly property var val: HyprConfigService.value(key)
    function set(v) { HyprConfigService.set(key, v); }
    modified: HyprConfigService.isOverridden(key)
    onReset: HyprConfigService.reset([key])
}
