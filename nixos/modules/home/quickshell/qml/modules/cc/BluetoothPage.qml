// Bluetooth, like macOS: paired devices connect or disconnect with a click,
// and nearby devices found while this page is open pair with a click.
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.components
import qs.services

SubPanel {
    id: page

    title: "Bluetooth"
    showSwitch: Bt.available
    checked: Bt.enabled
    footerText: "Bluetooth Settings…"
    onSwitchToggled: on => Bt.setEnabled(on)
    onFooterClicked: ShellState.openSettings("bluetooth")

    property var failures: ({})

    readonly property var paired: Bt.devices.filter(d => d.paired || d.bonded)
        .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    // BlueZ names devices without a name after their address; those are noise.
    readonly property var nearby: Bt.devices.filter(d => !d.paired && !d.bonded && d.deviceName !== "")
        .sort((a, b) => a.name.localeCompare(b.name)).slice(0, 12)

    function fail(device: var, text: string) {
        const f = Object.assign({}, failures);
        f[device.address] = text;
        failures = f;
        clearFailures.restart();
    }
    function activate(device: var) {
        if (device.pairing) {
            device.cancelPair();
        } else if (device.paired || device.bonded) {
            if (device.connected)
                device.disconnect();
            else
                device.connect();
        } else {
            device.trusted = true;
            device.pair();
        }
    }

    Component.onCompleted: Bt.startDiscovery(page)
    Component.onDestruction: Bt.stopDiscovery(page)
    Timer {
        id: clearFailures
        interval: 5000
        onTriggered: page.failures = {}
    }

    EmptyState {
        visible: !Bt.available || !Bt.enabled
        icon: "bluetooth-off"
        text: Bt.available ? "Bluetooth is off" : "No Bluetooth adapter"
    }

    SectionLabel {
        text: "Devices"
        visible: Bt.enabled && page.paired.length > 0
    }
    Repeater {
        model: Bt.enabled ? page.paired : []
        delegate: deviceRow
    }

    SectionLabel {
        text: "Nearby devices"
        visible: Bt.enabled
        busy: Bt.adapter?.discovering ?? false
    }
    Repeater {
        model: Bt.enabled ? page.nearby : []
        delegate: deviceRow
    }
    ListRow {
        visible: Bt.enabled && page.nearby.length === 0
        title: "Searching…"
        interactive: false
    }

    Component {
        id: deviceRow

        ListRow {
            id: row
            required property var modelData
            readonly property var device: modelData
            readonly property bool working: device.pairing
                || device.state === BluetoothDeviceState.Connecting
                || device.state === BluetoothDeviceState.Disconnecting

            icon: Bt.deviceIcon(device)
            title: device.name
            selected: device.connected
            busy: working
            subtitle: page.failures[device.address] ?? (device.pairing ? "Pairing…"
                : device.state === BluetoothDeviceState.Connecting ? "Connecting…"
                : device.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…"
                : device.connected ? "Connected" : "")
            error: page.failures[device.address] !== undefined
            onClicked: page.activate(device)
            onRightClicked: if (device.paired) device.forget()

            Label {
                visible: row.device.batteryAvailable && !row.working
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(row.device.battery * 100) + "%"
                dim: true
                size: Theme.textSmall * 0.9
            }
            Icon {
                visible: row.device.batteryAvailable && !row.working
                anchors.verticalCenter: parent.verticalCenter
                name: Bt.batteryIcon(row.device.battery)
                size: 13
                color: row.device.battery < 0.15 ? Theme.colors.urgent : Theme.colors.text
            }

            // A freshly paired device connects straight away.
            Connections {
                target: row.device
                function onPairedChanged() {
                    if (row.device.paired && !row.device.connected)
                        row.device.connect();
                }
                function onPairingChanged() {
                    if (!row.device.pairing && !row.device.paired)
                        page.fail(row.device, "Couldn't pair");
                }
            }
        }
    }
}
