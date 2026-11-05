pragma Singleton
// Battery level and charging state from UPower.
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    readonly property var device: UPower.displayDevice
    readonly property bool present: device?.isLaptopBattery ?? false
    readonly property real level: device?.percentage ?? 0
    readonly property bool charging: device?.state === UPowerDeviceState.Charging
        || device?.state === UPowerDeviceState.FullyCharged

    readonly property string icon: charging ? "battery-charging"
        : level > 0.8 ? "battery-full" : level > 0.4 ? "battery-medium" : level > 0.15 ? "battery-low" : "battery"
}
