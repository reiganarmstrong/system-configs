// A popup on the focused screen: covers the screen invisibly so a click
// outside the content closes it, and fades and scales the content in.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services

PanelWindow {
    id: popup

    required property string name
    default property alias content: holder.data
    // Where the content sits: "top-right", "top" or "center".
    property string placement: "top-right"
    property bool keyboard: false
    // Return true to consume Esc (e.g. to go back a page) instead of closing.
    property var escapeHandler: null
    readonly property bool open: ShellState.openPanel === name

    screen: Quickshell.screens.find(s => Hyprland.monitorFor(s) === Hyprland.focusedMonitor) ?? null
    visible: open || fade.running
    color: "transparent"
    WlrLayershell.namespace: "shell-" + name
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open && keyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.close()
    }

    Item {
        id: holder

        width: childrenRect.width
        height: childrenRect.height
        x: popup.placement === "top-right" ? parent.width - width - 10
            : (parent.width - width) / 2
        y: popup.placement === "center" ? parent.height * 0.22 : 44

        opacity: popup.open ? 1 : 0
        scale: Prefs.get("reduceMotion", false) || popup.open ? 1 : 0.96
        transformOrigin: popup.placement === "top-right" ? Item.TopRight : Item.Top

        Behavior on opacity {
            NumberAnimation { id: fade; duration: Prefs.get("reduceMotion", false) ? 0 : 160; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: Prefs.get("reduceMotion", false) ? 0 : 200; easing.type: Easing.OutCubic }
        }

        // Clicks inside the content must not reach the close area.
        MouseArea {
            anchors.fill: parent
            z: -1
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: popup.open
        onActivated: {
            if (!(popup.escapeHandler && popup.escapeHandler()))
                ShellState.close();
        }
    }
}
