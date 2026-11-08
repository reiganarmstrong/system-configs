// The dock: pinned and running apps along the bottom. It stays hidden until
// the pointer touches the bottom edge, and hides again when it leaves.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services

Scope {
    id: dock

    required property ShellScreen screen
    property bool shown: false

    // Pinned apps first, then other running apps, each once.
    readonly property var running: ToplevelManager.toplevels.values.map(t => t.appId).filter(id => id !== "")
    readonly property var entries: {
        // byId() isn't reactive; reading the list re-runs this when it loads.
        if (DesktopEntries.applications.values.length === 0)
            return [];
        const ids = [...Theme.data.dock.pinned];
        for (const cls of running) {
            const entry = DesktopEntries.heuristicLookup(cls);
            if (entry && !ids.includes(entry.id))
                ids.push(entry.id);
        }
        return ids.map(id => DesktopEntries.byId(id)).filter(e => e);
    }

    function isRunning(entry: var): bool {
        return running.some(cls => DesktopEntries.heuristicLookup(cls)?.id === entry.id);
    }

    // A one-pixel strip on the bottom edge that reveals the dock.
    PanelWindow {
        screen: dock.screen
        WlrLayershell.namespace: "shell-dock-trigger"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        anchors {
            bottom: true
            left: true
            right: true
        }
        implicitHeight: 1

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: dock.shown = true
        }
    }

    PanelWindow {
        screen: dock.screen
        visible: dock.shown || slide.running
        WlrLayershell.namespace: "shell-dock"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        anchors.bottom: true
        implicitWidth: panel.width + 20
        implicitHeight: panel.height + 20
        BackgroundEffect.blurRegion: Region {
            item: panel
            radius: panel.radius
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onExited: hideTimer.restart()
            onEntered: hideTimer.stop()
        }

        Timer {
            id: hideTimer
            interval: 400
            onTriggered: dock.shown = false
        }

        Glass {
            id: panel
            anchors.horizontalCenter: parent.horizontalCenter
            y: dock.shown ? parent.height - height - 8 : parent.height
            width: row.implicitWidth + 16
            height: 60
            radius: 20

            Behavior on y {
                NumberAnimation { id: slide; duration: Prefs.get("reduceMotion", false) ? 0 : 220; easing.type: Easing.OutCubic }
            }

            Row {
                id: row
                anchors.centerIn: parent
                spacing: 6

                Repeater {
                    model: dock.entries

                    Item {
                        id: app
                        required property var modelData
                        width: 48
                        height: 48

                        Image {
                            anchors.centerIn: parent
                            width: area.containsMouse ? 44 : 40
                            height: width
                            source: Quickshell.iconPath(app.modelData.icon, "application-x-executable")
                            sourceSize: Qt.size(96, 96)
                            Behavior on width { NumberAnimation { duration: 120 } }
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: -4
                            width: 14
                            height: 3
                            radius: 2
                            color: Theme.colors.text
                            visible: dock.isRunning(app.modelData)
                        }
                        MouseArea {
                            id: area
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: AppLaunch.launch(app.modelData)
                        }
                    }
                }
            }
        }
    }
}
