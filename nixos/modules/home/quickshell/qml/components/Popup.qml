// A popup on the focused screen: covers the screen invisibly so a click
// outside the content closes it, and fades and scales the content in.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

PanelWindow {
    id: popup

    required property string name
    default property alias content: holder.data
    // Where the content sits: "top-right", "top" or "center".
    property string placement: "top-right"
    property bool keyboard: false
    // Corner radius of the content's glass, for the blur behind it.
    property real surfaceRadius: Theme.radius.panel
    // Return true to consume Esc (e.g. to go back a page) instead of closing.
    property var escapeHandler: null
    readonly property bool open: ShellState.openPanel === name
    // On screen: from opening until the closing fade has finished. Set
    // explicitly, not bound to `open || fade.running`: on closing, that
    // binding can read false for an instant before the fade starts, and the
    // blink unloads and reloads whatever the popup holds.
    property bool shown: false
    onOpenChanged: {
        if (open)
            shown = true;
        else if (holder.opacity === 0)
            shown = false;
    }

    screen: Niri.focusedScreen()
    visible: shown
    color: "transparent"
    WlrLayershell.namespace: "shell-" + name
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open && keyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    // Bar buttons remain clickable while a menu is open.
    mask: Region {
        y: Theme.barHeight
        width: popup.width
        height: Math.max(0, popup.height - Theme.barHeight)
    }
    // The window covers the screen, so only the content is blurred. niri
    // can't fade a blur, so it is on only while the glass is mostly drawn:
    // off as soon as closing starts, on once opening is three-quarters done.
    // Otherwise the blur outlives the faded glass and the sharp background
    // pops back in one frame as the window closes.
    readonly property bool blurred: open && holder.opacity > 0.75
    readonly property Region blurShape: Region {
        id: blurRegion
        item: holder
        radius: popup.surfaceRadius
    }
    BackgroundEffect.blurRegion: blurred ? blurShape : null
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

    // Keep this outside holder: including a fill-sized child in childrenRect
    // prevents the holder and its blur region from shrinking with the glass.
    MouseArea {
        anchors.fill: holder
    }

    Item {
        id: holder

        width: childrenRect.width
        height: childrenRect.height
        // Bar menus hang just under the solid bar, flush with its right
        // edge; centred ones sit a little above the middle of the screen.
        readonly property real restY: popup.placement === "center" ? parent.height * 0.22 : Theme.popupTop
        // A short drop from the bar as the menu opens.
        property real drop: Prefs.get("reduceMotion", false) || popup.open ? 0 : -6

        x: popup.placement === "top-right" ? parent.width - width - 8
            : (parent.width - width) / 2
        y: restY + drop

        opacity: popup.open ? 1 : 0
        scale: Prefs.get("reduceMotion", false) || popup.open ? 1 : 0.97
        transformOrigin: popup.placement === "top-right" ? Item.TopRight : Item.Top
        // Region tracks geometry changes, but not item transforms.
        onScaleChanged: blurRegion.changed()
        onOpacityChanged: if (opacity === 0 && !popup.open) popup.shown = false

        Behavior on opacity {
            NumberAnimation { duration: Prefs.get("reduceMotion", false) ? 0 : 140; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: Prefs.get("reduceMotion", false) ? 0 : 170; easing.type: Easing.OutCubic }
        }
        Behavior on drop {
            NumberAnimation { duration: Prefs.get("reduceMotion", false) ? 0 : 170; easing.type: Easing.OutCubic }
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
