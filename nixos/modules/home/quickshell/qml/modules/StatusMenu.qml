// A bar status icon's own menu: one page, such as NetworkPage, in a popup of
// its own. The control centre opens the same page components inside its
// grid, so changing NetworkPage changes both.
import QtQuick
import qs.components
import qs.services

Popup {
    id: root

    // The page to show, as a Component whose root is a SubPanel.
    property Component page
    // The loaded page, for tests and the IPC status.
    readonly property Item pageItem: host.item

    surfaceRadius: 26
    placement: "top-right"
    // Keyboard input for Esc and the Wi-Fi password field.
    keyboard: true
    escapeHandler: () => host.item?.handleEscape?.() ?? false

    readonly property real padding: Theme.spacing.panel
    readonly property real maxPanelHeight: Math.min(560, root.height - 68)

    Glass {
        width: Theme.menuWidth
        height: host.implicitHeight + root.padding * 2
        radius: 26
        fillOpacity: Prefs.get("panelOpacity", Theme.opacity.panel)
        clip: false

        // Animate height changes inside the page, not its growth while it
        // opens: lists fill in for a moment after loading, and animating that
        // leaves rows drawn below the glass.
        Behavior on height {
            enabled: host.settled
            NumberAnimation { duration: Motion.ms(240); easing.type: Easing.OutCubic }
        }

        Loader {
            id: host
            property bool settled: false

            x: root.padding
            y: root.padding
            width: parent.width - root.padding * 2
            // Loaded only while the popup is on screen, so the Wi-Fi scan and
            // Bluetooth discovery stop once the menu has faded out.
            active: root.visible
            sourceComponent: root.page

            onLoaded: {
                item.maxHeight = Qt.binding(() => root.maxPanelHeight - root.padding * 2);
                item.back.connect(ShellState.close);
            }
            onItemChanged: if (!item) settled = false
        }
        Timer {
            interval: 300
            running: root.open && host.item !== null && !host.settled
            onTriggered: host.settled = true
        }
    }
}
