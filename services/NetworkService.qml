pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking

// Connection summary derived from Quickshell's NetworkManager backend (event driven).
Singleton {
    id: root

    readonly property var devices: Networking.devices ? Networking.devices.values : []
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi && d.connected) ?? null

    // "wired" | "wifi" | "none"
    readonly property string kind: wired ? "wired" : wifi ? "wifi" : "none"
    readonly property bool online: kind !== "none"

    readonly property var wifiNet: {
        if (!wifi || !wifi.networks) return null;
        return wifi.networks.values.find(n => n.connected) ?? null;
    }
    readonly property string name: kind === "wifi" ? (wifiNet ? wifiNet.name : "Wi-Fi") : kind === "wired" ? wired.name : "Offline"
    readonly property real strength: wifiNet && wifiNet.signalStrength !== undefined ? wifiNet.signalStrength : 0
    readonly property string address: kind === "wired" ? wired.address : kind === "wifi" ? wifi.address : ""

    function icon() {
        return kind === "wired" ? "" : kind === "wifi" ? "" : "";
    }
}
