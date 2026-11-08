import QtQuick
import qs.components.settings
import qs.modules.cc as Radio
import qs.services

Column {
    required property var host
    spacing: 10
    Radio.BluetoothPage {
        title: "Devices"
        scrolls: false
        footerText: ""
    }
    SettingRow {
        title: "Device actions"
        detail: "Select a saved device to connect or disconnect. Select a nearby device to pair. Right-click a saved device to forget it."
    }
    SettingAction {
        title: "Advanced Bluetooth options"
        detail: "Adapter names, special device services and pairing-agent options."
        buttonText: "Open manager…"
        enabled: Bt.available
        onActivated: host.launch(["blueman-manager"])
    }
}
