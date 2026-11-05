// New notifications, stacked under the bar's right side. Each times out
// into the notification centre's history.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.components
import qs.services

PanelWindow {
    screen: Quickshell.screens.find(s => Hyprland.monitorFor(s) === Hyprland.focusedMonitor) ?? null
    visible: Notifs.popups.length > 0 && !Session.locked
    color: "transparent"
    WlrLayershell.namespace: "shell-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        right: true
    }
    margins {
        top: 44
        right: 10
    }
    implicitWidth: 360
    implicitHeight: stack.implicitHeight

    Column {
        id: stack
        width: parent.width
        spacing: 8

        Repeater {
            model: Notifs.popups

            NotificationCard {
                required property var modelData
                width: stack.width
                notification: modelData
                onDismissed: Notifs.dismissPopup(modelData)

                Timer {
                    running: true
                    interval: modelData.expireTimeout > 0 ? modelData.expireTimeout * 1000 : 6000
                    onTriggered: Notifs.dismissPopup(parent.modelData)
                }
            }
        }
    }
}
