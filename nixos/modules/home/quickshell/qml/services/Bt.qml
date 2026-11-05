pragma Singleton
// Bluetooth adapter state from BlueZ.
import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property var connected: Bluetooth.devices.values.filter(d => d.connected)

    readonly property string status: !available ? "Unavailable" : !enabled ? "Off"
        : connected.length > 0 ? connected[0].name : "On"

    function setEnabled(on: bool) {
        if (adapter)
            adapter.enabled = on;
    }
}
