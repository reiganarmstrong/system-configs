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
    // Held while the control centre or clipboard is open; they
    // still reach the notification centre.
    visible: Notifs.popups.length > 0 && !Session.locked && !["control", "clipboard"].includes(ShellState.openPanel)
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
                    running: Prefs.get("bannerSeconds", 6) > 0
                    interval: Math.max(1, Prefs.get("bannerSeconds", 6)) * 1000
                    onTriggered: Notifs.dismissPopup(parent.modelData)
                }
            }
        }
    }
}
