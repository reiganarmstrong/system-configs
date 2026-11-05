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

    // The control centre's Caffeine keeps the screen awake through this.
    IdleInhibitor {
        window: bar
        enabled: Session.caffeine
    }

    // Workspaces: a number for each, the active one on a white circle.
    Pill {
        padding: 4
        spacing: 2

        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            model: Hyprland.workspaces.values
                .filter(w => w.id > 0 && w.monitor === bar.monitor)
                .sort((a, b) => a.id - b.id)

            Rectangle {
                required property var modelData
                readonly property bool current: modelData.active

                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                radius: 10
                color: current ? Theme.colors.accent : area.containsMouse ? Theme.tileFillHover : "transparent"

                Behavior on color {
                    ColorAnimation { duration: 160 }
                }

                Label {
                    anchors.centerIn: parent
                    text: parent.modelData.id
                    size: Theme.textSmall
                    weight: parent.current ? Font.Bold : Font.Medium
                    color: parent.current ? Theme.colors.accentText : Theme.colors.textDim
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: parent.modelData.activate()
                }
            }
        }
    }

    // Clock; opens the notification centre.
    Pill {
        anchors.centerIn: parent
        clickable: true
        onClicked: ShellState.toggle("dash")

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
        clickable: true
        onClicked: ShellState.toggle("control")

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
