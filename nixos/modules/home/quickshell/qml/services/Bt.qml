pragma Singleton
// Bluetooth adapter state from BlueZ.
import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    // The lowest-numbered controller, as BlueZ itself prefers; Quickshell's
    // default can be another one when there are several.
    readonly property var adapter: Bluetooth.adapters.values.slice().sort((a, b) => a.adapterId.localeCompare(b.adapterId))[0]
        ?? Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property var connected: Bluetooth.devices.values.filter(d => d.connected)

    readonly property string status: !available ? "Unavailable" : !enabled ? "Off"
        : connected.length > 0 ? connected[0].name : "On"

    // Devices seen by the default adapter. (BlueZ lists every adapter's
    // devices, so a second controller would show the machine itself.)
    readonly property var devices: Bluetooth.devices.values.filter(d => d.adapter === adapter)

    // BlueZ's freedesktop icon name as a Lucide glyph.
    function deviceIcon(device: var): string {
        const icons = {
            "audio-headset": "headset",
            "audio-headphones": "headphones",
            "audio-card": "speaker",
            "audio-speaker": "speaker",
            "input-mouse": "mouse",
            "input-keyboard": "keyboard",
            "input-gaming": "gamepad-2",
            "input-tablet": "tablet",
            "phone": "smartphone",
            "computer": "laptop",
            "video-display": "monitor",
            "camera-photo": "camera",
            "camera-video": "camera",
            "printer": "printer",
        };
        return icons[device?.icon ?? ""] ?? "bluetooth";
    }
    function batteryIcon(level: real): string {
        return level >= 0.7 ? "battery-full" : level >= 0.35 ? "battery-medium" : level >= 0.15 ? "battery-low" : "battery-warning";
    }

    function setEnabled(on: bool) {
        if (adapter)
            adapter.enabled = on;
    }
}
