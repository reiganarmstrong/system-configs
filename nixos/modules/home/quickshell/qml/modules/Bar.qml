// The top bar: three floating pills for workspaces, the clock and status.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.components
import qs.services

PanelWindow {
    id: bar

    WlrLayershell.namespace: "shell-bar"
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 40
    color: "transparent"

    readonly property var monitor: Hyprland.monitorFor(screen)

    // Workspaces: a dot for each, the active one stretched into a bar.
    Pill {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            model: Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor === bar.monitor)

            Rectangle {
                required property var modelData
                readonly property bool current: modelData.active

                anchors.verticalCenter: parent.verticalCenter
                width: current ? 22 : 7
                height: 7
                radius: 4
                color: current ? Theme.colors.text : Theme.withAlpha(Theme.colors.text, 0.45)

                Behavior on width {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    onClicked: parent.modelData.activate()
                }
            }
        }
    }

    // Clock.
    Pill {
        anchors.centerIn: parent

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        Label {
            dim: true
            text: Qt.formatDate(clock.date, "ddd d MMM")
        }
        Label {
            weight: Font.Bold
            text: Qt.formatTime(clock.date, "h:mm")
        }
    }

    // Status: network, volume and battery; opens the control centre.
    Pill {
        id: status
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter

        Icon { name: Net.icon; size: 15 }
        Icon { name: Audio.icon; size: 15 }
        Row {
            visible: Battery.present
            spacing: 4
            Icon { name: Battery.icon; size: 15 }
            Label {
                size: Theme.textSmall
                text: Math.round(Battery.level * 100) + "%"
            }
        }
    }
}
