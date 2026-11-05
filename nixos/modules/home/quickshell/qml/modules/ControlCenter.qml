// The control centre, dropping from the status pill: session buttons,
// connectivity, toggles, brightness, volume, now playing and shortcuts.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.components
import qs.services

Popup {
    id: root
    name: "control"
    placement: "top-right"

    Glass {
        width: 400
        height: layout.implicitHeight + Theme.spacing.panel * 2

        ColumnLayout {
            id: layout
            anchors.fill: parent
            anchors.margins: Theme.spacing.panel
            spacing: Theme.spacing.tile

            // Who is logged in, and the session buttons.
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 36
                    height: 36
                    radius: 18
                    color: Theme.colors.accent
                    Label {
                        anchors.centerIn: parent
                        text: Theme.user.fullName.charAt(0)
                        color: Theme.colors.accentText
                        weight: Font.Bold
                    }
                }
                Column {
                    Layout.fillWidth: true
                    Label { text: Theme.user.name; weight: Font.Bold }
                    Label { text: Session.uptime; dim: true; size: Theme.textSmall }
                }
                RoundButton { icon: "lock"; diameter: 32; onClicked: Session.lock() }
                RoundButton { icon: "moon"; diameter: 32; onClicked: Session.suspend() }
                RoundButton { icon: "log-out"; diameter: 32; onClicked: Session.logout() }
                RoundButton { icon: "rotate-ccw"; diameter: 32; onClicked: Session.reboot() }
                RoundButton { icon: "power"; diameter: 32; onClicked: Session.poweroff() }
            }

            // Connectivity on the left; Do Not Disturb and two toggles on the right.
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing.tile

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: connectivity.implicitHeight + 8
                    radius: Theme.radius.tile
                    color: Theme.tileFill

                    Column {
                        id: connectivity
                        anchors.fill: parent
                        anchors.margins: 4

                        Tile {
                            width: parent.width
                            flat: true
                            icon: Net.icon
                            title: Net.title
                            subtitle: Net.status
                            active: Net.wiredUp || Net.wifiUp
                            onClicked: Net.setWifi(!Net.wifiOn)
                        }
                        Tile {
                            width: parent.width
                            flat: true
                            icon: Bt.enabled ? "bluetooth" : "bluetooth-off"
                            title: "Bluetooth"
                            subtitle: Bt.status
                            active: Bt.enabled
                            onClicked: Bt.setEnabled(!Bt.enabled)
                        }
                        Tile {
                            readonly property bool airplane: !Net.wifiOn && !Bt.enabled
                            width: parent.width
                            flat: true
                            icon: "plane"
                            title: "Airplane Mode"
                            subtitle: airplane ? "On" : "Off"
                            active: airplane
                            onClicked: {
                                Net.setWifi(airplane);
                                Bt.setEnabled(airplane);
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    spacing: Theme.spacing.tile

                    Tile {
                        Layout.fillWidth: true
                        icon: Notifs.doNotDisturb ? "bell-off" : "bell"
                        title: "Do Not Disturb"
                        subtitle: Notifs.doNotDisturb ? "On" : "Off"
                        active: Notifs.doNotDisturb
                        onClicked: Notifs.doNotDisturb = !Notifs.doNotDisturb
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        RoundButton {
                            Layout.fillWidth: true
                            icon: "sun-moon"
                            caption: "Night Light"
                            active: NightLight.enabled
                            onClicked: NightLight.enabled = !NightLight.enabled
                        }
                        RoundButton {
                            Layout.fillWidth: true
                            icon: "coffee"
                            caption: "Caffeine"
                            active: Session.caffeine
                            onClicked: Session.caffeine = !Session.caffeine
                        }
                    }
                }
            }

            Section {
                Layout.fillWidth: true
                title: "Display"
                visible: Brightness.available

                Slider {
                    width: parent.width
                    icon: "sun"
                    value: Brightness.level
                    onMoved: v => Brightness.set(v)
                }
            }

            Section {
                Layout.fillWidth: true
                title: "Sound"
                detail: Audio.sinkName

                Slider {
                    width: parent.width
                    icon: Audio.icon
                    value: Audio.muted ? 0 : Audio.volume
                    onMoved: v => Audio.setVolume(v)
                }
            }

            MediaCard {
                Layout.fillWidth: true
                visible: Media.player !== null
            }

            // Shortcuts.
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4

                RoundButton {
                    readonly property var names: ["Saver", "Balanced", "Performance"]
                    Layout.fillWidth: true
                    icon: "gauge"
                    caption: names[PowerProfiles.profile] ?? "Power"
                    active: PowerProfiles.profile !== PowerProfile.Balanced
                    onClicked: {
                        const next = PowerProfiles.profile === PowerProfile.Balanced
                            ? (PowerProfiles.hasPerformanceProfile ? PowerProfile.Performance : PowerProfile.PowerSaver)
                            : PowerProfiles.profile === PowerProfile.Performance ? PowerProfile.PowerSaver
                            : PowerProfile.Balanced;
                        PowerProfiles.profile = next;
                    }
                }
                RoundButton {
                    Layout.fillWidth: true
                    icon: Audio.micMuted ? "mic-off" : "mic"
                    caption: "Microphone"
                    active: !Audio.micMuted
                    onClicked: Audio.toggleMic()
                }
                RoundButton {
                    Layout.fillWidth: true
                    icon: "scan"
                    caption: "Screenshot"
                    onClicked: {
                        ShellState.close();
                        Session.run(["sh", "-c", "sleep 0.3; grim -g \"$(slurp)\" - | wl-copy"]);
                    }
                }
                RoundButton {
                    Layout.fillWidth: true
                    icon: "pipette"
                    caption: "Picker"
                    onClicked: {
                        ShellState.close();
                        Session.run(["sh", "-c", "sleep 0.3; hyprpicker --autocopy"]);
                    }
                }
            }
        }
    }
}
