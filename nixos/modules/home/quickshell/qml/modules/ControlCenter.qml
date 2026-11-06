// The control centre, dropping from the status pill. Laid out on a grid of
// cells like macOS: capsule toggles span two columns, small toggles one,
// now playing two rows, and the sliders the full width. Wi-Fi,
// Bluetooth, Sound and Now Playing open detail pages that replace the grid
// inside the same panel.
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.components
import qs.modules.cc
import qs.services

Popup {
    id: root
    name: "control"
    placement: "top-right"
    // Keyboard input for Esc and the Wi-Fi password field.
    keyboard: true
    escapeHandler: () => root.handleEscape()

    // "", "network", "bluetooth", "sound" or "media".
    property string page: ""
    // The page still on screen while fading out after going back.
    property string shownPage: ""
    readonly property real maxPanelHeight: Math.min(560, root.height - 68)

    function openPage(name: string) {
        shownPage = name;
        page = name;
    }
    function back(): bool {
        if (page === "")
            return false;
        page = "";
        return true;
    }
    function handleEscape(): bool {
        const item = pageHost.item;
        if (item && item.handleEscape && item.handleEscape())
            return true;
        return back();
    }
    function resetPage() {
        page = "";
        shownPage = "";
    }
    // Preserve the current page and panel height through the outer fade.
    // Deferring the hidden check avoids a transient visible=false before the
    // opacity animation starts. Unloading afterwards stops page discovery.
    onOpenChanged: if (open) resetPage()
    onVisibleChanged: if (!visible) Qt.callLater(() => {
        if (!root.visible && !root.open) root.resetPage();
    })

    readonly property real cell: 66
    readonly property real cellWidth: 80
    readonly property real gap: 11
    readonly property real wide: cellWidth * 2 + gap
    readonly property real full: cellWidth * 4 + gap * 3

    Glass {
        width: root.full + 28
        height: (root.page === "" ? layout.implicitHeight : pageHost.implicitHeight) + 28
        radius: 26
        fillOpacity: Prefs.get("panelOpacity", 0.55)
        clip: false

        Behavior on height { NumberAnimation { duration: Motion.ms(240); easing.type: Easing.OutCubic } }

        // A page in place of the grid, sliding in from the right.
        Loader {
            id: pageHost
            x: 14 + (root.page !== "" ? 0 : 16)
            y: 14
            width: root.full
            opacity: root.page !== "" ? 1 : 0
            visible: opacity > 0
            active: root.shownPage !== ""
            sourceComponent: ({
                network: networkPage,
                bluetooth: bluetoothPage,
                sound: soundPage,
                media: mediaPage,
            })[root.shownPage] ?? null

            Behavior on opacity {
                NumberAnimation { duration: Motion.ms(root.page !== "" ? 180 : 120); easing.type: Easing.OutCubic }
            }
            Behavior on x {
                NumberAnimation { duration: Motion.ms(root.page !== "" ? 180 : 120); easing.type: Easing.OutCubic }
            }
            onOpacityChanged: if (opacity === 0 && root.page === "") root.shownPage = ""
        }

        Component {
            id: networkPage
            NetworkPage { maxHeight: root.maxPanelHeight - 28; onBack: root.back() }
        }
        Component {
            id: bluetoothPage
            BluetoothPage { maxHeight: root.maxPanelHeight - 28; onBack: root.back() }
        }
        Component {
            id: soundPage
            SoundPage { maxHeight: root.maxPanelHeight - 28; onBack: root.back() }
        }
        Component {
            id: mediaPage
            MediaPage { maxHeight: root.maxPanelHeight - 28; onBack: root.back(); onFinished: root.back() }
        }

        Column {
            id: layout
            x: 14 + (root.page === "" ? 0 : -12)
            y: 14
            width: root.full
            spacing: root.gap
            opacity: root.page === "" ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: Motion.ms(root.page === "" ? 180 : 120); easing.type: Easing.OutCubic }
            }
            Behavior on x {
                NumberAnimation { duration: Motion.ms(root.page === "" ? 180 : 120); easing.type: Easing.OutCubic }
            }

            // Who is logged in, and the session buttons.
            Item {
                width: parent.width
                height: 32

                Rectangle {
                    id: avatar
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30
                    height: 30
                    radius: 15
                    color: Theme.colors.accent
                    Label {
                        anchors.centerIn: parent
                        text: Theme.user.fullName.charAt(0)
                        color: Theme.colors.accentText
                        weight: Font.Bold
                    }
                }
                Column {
                    anchors.left: avatar.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    Label { text: Theme.user.name; weight: Font.Bold; size: Theme.textSmall }
                    Label { text: Session.uptime; dim: true; size: Theme.textSmall * 0.9 }
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Repeater {
                        model: [
                            { icon: "settings", run: () => ShellState.openSettings("appearance") },
                            { icon: "lock", run: () => Session.lock() },
                            { icon: "moon", run: () => Session.suspend() },
                            { icon: "log-out", run: () => Session.logout() },
                            { icon: "rotate-ccw", run: () => Session.reboot() },
                            { icon: "power", run: () => Session.poweroff() },
                        ]
                        Rectangle {
                            required property var modelData
                            width: 26
                            height: 26
                            radius: 13
                            color: area.containsMouse ? Theme.withAlpha("#ffffff", 0.14) : "transparent"
                            Icon { anchors.centerIn: parent; name: parent.modelData.icon; size: 13 }
                            MouseArea {
                                id: area
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: parent.modelData.run()
                            }
                        }
                    }
                }
            }

            // Wi-Fi and Bluetooth beside now playing.
            Row {
                spacing: root.gap

                Column {
                    spacing: root.gap
                    PillToggle {
                        width: root.wide
                        height: root.cell
                        icon: Net.icon
                        title: Net.title
                        subtitle: Net.status
                        active: Net.wiredUp || Net.wifiUp
                        openable: true
                        onToggled: if (Net.wifi) Net.setWifi(!Net.wifiOn)
                        onOpened: root.openPage("network")
                    }
                    PillToggle {
                        width: root.wide
                        height: root.cell
                        icon: Bt.enabled ? "bluetooth" : "bluetooth-off"
                        title: "Bluetooth"
                        subtitle: Bt.status
                        active: Bt.enabled
                        enabled: Bt.available
                        opacity: enabled ? 1 : 0.5
                        openable: true
                        onToggled: Bt.setEnabled(!Bt.enabled)
                        onOpened: root.openPage("bluetooth")
                    }
                }

                MediaCard {
                    width: root.wide
                    height: root.cell * 2 + root.gap
                    onOpened: root.openPage("media")
                }
            }

            // Focus with Airplane Mode and Caffeine; Power with the microphone
            // and colour picker.
            Row {
                spacing: root.gap

                PillToggle {
                    width: root.wide
                    height: root.cell
                    icon: Notifs.doNotDisturb ? "bell-off" : "bell"
                    title: "Focus"
                    subtitle: Notifs.doNotDisturb ? "Do Not Disturb" : "Off"
                    active: Notifs.doNotDisturb
                    onClicked: Prefs.set("doNotDisturb", !Notifs.doNotDisturb)
                }
                CircleToggle {
                    width: root.cellWidth
                    height: root.cell
                    readonly property bool airplane: !Net.wifiOn && !Bt.enabled
                    icon: "plane"
                    active: airplane
                    enabled: Net.wifi !== null || Bt.available
                    opacity: enabled ? 1 : 0.5
                    onClicked: {
                        Net.setWifi(airplane);
                        Bt.setEnabled(airplane);
                    }
                }
                CircleToggle {
                    width: root.cellWidth
                    height: root.cell
                    icon: "coffee"
                    active: Session.caffeine
                    onClicked: Session.caffeine = !Session.caffeine
                }
            }

            Row {
                spacing: root.gap

                // The icon follows the profile: leaf, gauge or bolt.
                PillToggle {
                    readonly property var names: ["Power Saver", "Balanced", "Performance"]
                    width: root.wide
                    height: root.cell
                    icon: ["leaf", "gauge", "zap"][PowerProfiles.profile] ?? "gauge"
                    title: "Power"
                    subtitle: names[PowerProfiles.profile] ?? ""
                    active: PowerProfiles.profile !== PowerProfile.Balanced
                    onClicked: {
                        PowerProfiles.profile = PowerProfiles.profile === PowerProfile.Balanced
                            ? (PowerProfiles.hasPerformanceProfile ? PowerProfile.Performance : PowerProfile.PowerSaver)
                            : PowerProfiles.profile === PowerProfile.Performance ? PowerProfile.PowerSaver
                            : PowerProfile.Balanced;
                    }
                }
                CircleToggle {
                    width: root.cellWidth
                    height: root.cell
                    icon: Audio.micMuted ? "mic-off" : "mic"
                    active: !Audio.micMuted
                    onClicked: Audio.toggleMic()
                }
                CircleToggle {
                    width: root.cellWidth
                    height: root.cell
                    icon: "pipette"
                    onClicked: {
                        ShellState.close();
                        Session.run(["sh", "-c", "sleep 0.3; hyprpicker --autocopy"]);
                    }
                }
            }

            SliderTile {
                width: root.full
                title: "Display"
                onTitleClicked: ShellState.openSettings("display")
                detail: Brightness.available ? "" : "Not adjustable"
                enabled: Brightness.available
                opacity: enabled ? 1 : 0.5
                startIcon: "sun-dim"
                endIcon: "sun"
                value: Brightness.level
                onMoved: v => Brightness.set(v)
            }

            SliderTile {
                width: root.full
                title: "Sound"
                openable: true
                onOpened: root.openPage("sound")
                detail: Audio.sinkName
                startIcon: "volume"
                endIcon: "volume-2"
                value: Audio.muted ? 0 : Audio.volume
                onMoved: v => Audio.setVolume(v)
            }
        }
    }
}
