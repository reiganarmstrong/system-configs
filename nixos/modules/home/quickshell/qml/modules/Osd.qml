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

    function show(icon: string, value: real) {
        osd.icon = icon;
        osd.value = value;
        shown = true;
        hide.restart();
    }

    screen: Niri.focusedScreen()
    visible: shown || fade.running
    color: "transparent"
    WlrLayershell.namespace: "shell-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    anchors.bottom: true
    margins.bottom: 90
    implicitWidth: 280
    implicitHeight: 52
    BackgroundEffect.blurRegion: Region {
        item: glass
        radius: glass.radius
    }

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
        Behavior on opacity { NumberAnimation { id: fade; duration: 180 } }

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
