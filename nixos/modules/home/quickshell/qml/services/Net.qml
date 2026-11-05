pragma Singleton
// Network state from NetworkManager, reduced to what the shell shows.
import QtQuick
import Quickshell
import Quickshell.Networking

Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null

    readonly property bool wiredUp: wired !== null
    readonly property bool wifiUp: wifi?.connected ?? false
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property var wifiNetwork: wifiUp ? wifi.networks.values.find(n => n.connected) ?? null : null

    readonly property string icon: wiredUp ? "ethernet-port" : wifiUp ? "wifi" : wifiOn ? "wifi" : "wifi-off"
    readonly property string title: wiredUp ? "Ethernet" : "Wi-Fi"
    readonly property string status: wiredUp ? "Connected" : wifiUp ? (wifiNetwork?.name ?? "Connected") : wifiOn ? "Not connected" : "Off"

    function setWifi(on: bool) {
        Networking.wifiEnabled = on;
    }
}
