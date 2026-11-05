// The wallpaper, drawn as a background layer on each screen.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

PanelWindow {
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "shell-wallpaper"
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: Theme.colors.background

    Image {
        anchors.fill: parent
        source: "file://" + Theme.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(width, height)
    }
}
