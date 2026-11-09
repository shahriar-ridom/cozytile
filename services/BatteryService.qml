pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Battery presence/percentage. `present` is false on desktops so the widget hides itself.
Singleton {
    id: root
    readonly property var dev: UPower.displayDevice
    readonly property bool present: dev !== null && dev.ready && dev.isPresent && dev.isLaptopBattery
    readonly property real percent: present ? dev.percentage * 100 : 0   // UPower reports 0..1
    readonly property bool charging: present && dev.state === UPowerDeviceState.Charging
    readonly property bool low: present && !charging && percent <= 15

    function icon() {
        if (charging) return "";
        const p = percent;
        return p > 87 ? "" : p > 62 ? "" : p > 37 ? "" : p > 12 ? "" : "";
    }
}
