// A short-lived level indicator for volume and brightness keys.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services

PanelWindow {
    id: osd

    property string icon: "volume-2"
    property real value: 0
    property bool shown: false
    // On screen until the fade-out ends; see Popup's `shown` for why this
    // isn't bound to `shown || fade.running`.
    property bool onScreen: false
    onShownChanged: if (shown) onScreen = true

    function show(icon: string, value: real) {
        osd.icon = icon;
        osd.value = value;
        shown = true;
        hide.restart();
    }

    screen: Niri.focusedScreen()
    visible: onScreen
    color: "transparent"
    WlrLayershell.namespace: "shell-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    anchors.bottom: true
    margins.bottom: 90
    implicitWidth: 280
    implicitHeight: 52
    // Blurred only while the glass is mostly drawn, like Popup, so the blur
    // doesn't outlive the fade and pop away when the window closes.
    readonly property Region blurShape: Region {
        item: glass
        radius: glass.radius
    }
    BackgroundEffect.blurRegion: shown && glass.opacity > 0.75 ? blurShape : null

    Timer {
        id: hide
        interval: 1400
        onTriggered: osd.shown = false
    }

    Glass {
        id: glass
        anchors.fill: parent
        radius: height / 2
        opacity: osd.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        onOpacityChanged: if (opacity === 0 && !osd.shown) osd.onScreen = false

        Row {
            anchors.centerIn: parent
            spacing: 14
            Icon { name: osd.icon; size: 18; anchors.verticalCenter: parent.verticalCenter }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 190
                height: 6
                radius: 3
                color: Theme.tileFill
                Rectangle {
                    width: parent.width * Math.min(1, osd.value)
                    height: parent.height
                    radius: 3
                    color: Theme.colors.text
                    Behavior on width { NumberAnimation { duration: 90 } }
                }
            }
        }
    }
}
