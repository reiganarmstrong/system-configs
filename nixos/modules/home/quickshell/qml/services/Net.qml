pragma Singleton
// Network state from NetworkManager, reduced to what the shell shows.
import QtQuick
import Quickshell
import Quickshell.Networking

Singleton {
    id: root
    property var scanOwners: []
    function startScan(owner: var): void {
        if (!scanOwners.includes(owner)) scanOwners = [...scanOwners, owner];
        updateScan();
    }
    function stopScan(owner: var): void {
        scanOwners = scanOwners.filter(o => o !== owner);
        updateScan();
    }
    function updateScan(): void { if (wifi) wifi.scannerEnabled = wifiOn && scanOwners.length > 0; }
    onWifiOnChanged: updateScan()
    onWifiChanged: updateScan()

    readonly property var devices: Networking.devices.values
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wiredDevices: devices.filter(d => d.type === DeviceType.Wired)
    readonly property bool hardwareEnabled: Networking.wifiHardwareEnabled

    readonly property bool wiredUp: wired !== null
    readonly property bool wifiUp: wifi?.connected ?? false
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property var wifiNetwork: wifiUp ? wifi.networks.values.find(n => n.connected) ?? null : null

    readonly property string icon: wiredUp ? "ethernet-port"
        : wifiUp ? signalIcon(wifiNetwork?.signalStrength ?? 1) : wifiOn ? "wifi-zero" : "wifi-off"
    readonly property string title: wiredUp ? "Ethernet" : "Wi-Fi"
    readonly property string status: wiredUp ? "Connected" : wifiUp ? (wifiNetwork?.name ?? "Connected") : wifiOn ? "Not connected" : "Off"

    // Signal strength (0..1) as one of Lucide's Wi-Fi glyphs.
    function signalIcon(strength: real): string {
        return strength >= 0.75 ? "wifi" : strength >= 0.5 ? "wifi-high" : strength >= 0.25 ? "wifi-low" : "wifi-zero";
    }
    // Open networks connect directly; WPA-Personal needs a password;
    // enterprise networks need Settings.
    function securityKind(security: int): string {
        switch (security) {
        case WifiSecurityType.Open:
        case WifiSecurityType.Owe:
            return "open";
        case WifiSecurityType.Wpa3SuiteB192:
        case WifiSecurityType.Wpa2Eap:
        case WifiSecurityType.WpaEap:
        case WifiSecurityType.DynamicWep:
        case WifiSecurityType.Leap:
            return "enterprise";
        case WifiSecurityType.Unknown:
            return "unknown";
        default:
            return "psk";
        }
    }

    function setWifi(on: bool) {
        Networking.wifiEnabled = on;
    }
}
