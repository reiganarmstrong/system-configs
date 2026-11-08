// New notifications, stacked under the bar's right side. Each times out
// into the notification centre's history.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services

PanelWindow {
    id: notifications
    property list<Region> cardRegions: []
    readonly property bool held: ["control", "network", "bluetooth", "sound", "clipboard"].includes(ShellState.openPanel)
    // Pairing agents ask for approval through notification actions. Keep
    // those reachable while the page that requested pairing stays open.
    readonly property var shownPopups: Notifs.popups.filter(n => !held || (n.actions?.length ?? 0) > 0)
    screen: Compositor.focusedScreen()
    visible: shownPopups.length > 0 && !Session.locked
    color: "transparent"
    WlrLayershell.namespace: "shell-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        right: true
    }
    margins {
        top: Theme.popupTop
        right: 8
    }
    implicitWidth: 360
    implicitHeight: stack.implicitHeight
    // One rounded blur region per card, so the gaps between them stay clear.
    BackgroundEffect.blurRegion: Region {
        regions: notifications.cardRegions
    }

    Column {
        id: stack
        width: parent.width
        spacing: 8

        Repeater {
            id: cards
            model: notifications.shownPopups
            // Each region lives with its card. Replacing the model destroys
            // the old cards, so index-based references can become stale.
            onItemAdded: (index, item) => notifications.cardRegions = [...notifications.cardRegions, item.blurRegion]
            onItemRemoved: (index, item) => notifications.cardRegions = notifications.cardRegions.filter(region => region !== item.blurRegion)

            NotificationCard {
                id: card
                readonly property Region blurRegion: Region {
                    item: card
                    radius: card.radius
                }
                required property var modelData
                width: stack.width
                notification: modelData
                onDismissed: Notifs.dismissPopup(modelData)

            }
        }
    }
}
