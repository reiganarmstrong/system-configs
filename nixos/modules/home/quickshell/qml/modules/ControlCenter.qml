// The control centre, dropping from the bar's status icons. Laid out on a grid of
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
    surfaceRadius: 26
    name: "control"
    placement: "top-right"
    // Keyboard input for Esc and the Wi-Fi password field.
    keyboard: true
    escapeHandler: () => root.handleEscape()

    // "", "network", "bluetooth", "sound" or "media".
    property string page: ""
    // The page still on screen while fading out after going back.
    property string shownPage: ""
    // Keep the entry route through the closing fade, like the shown page.
    property bool standalone: false
    readonly property real maxPanelHeight: Math.min(560, root.height - 68)

    function openPage(name: string) {
        shownPage = name;
        page = name;
        if (open)
            ShellState.controlPage = name;
    }
    function back(): bool {
        if (page === "")
            return false;
        if (standalone) {
            ShellState.close();
            return true;
        }
        page = "";
        ShellState.controlPage = "";
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
        standalone = false;
    }
    // Preserve the current page and panel height through the outer fade.
    // Deferring the hidden check avoids a transient visible=false before the
    // opacity animation starts. Unloading afterwards stops page discovery.
    onOpenChanged: if (open) {
        resetPage();
        standalone = ShellState.controlStandalone;
        if (ShellState.controlPage !== "")
            openPage(ShellState.controlPage);
    }
    Connections {
        target: ShellState
        function onControlStandaloneChanged() {
            if (root.open)
                root.standalone = ShellState.controlStandalone;
        }
        function onControlPageChanged() {
            if (root.open && root.page !== ShellState.controlPage)
                root.openPage(ShellState.controlPage);
        }
    }
    onVisibleChanged: if (!visible) Qt.callLater(() => {
        if (!root.visible && !root.open) root.resetPage();
    })

    readonly property real cell: 66
    readonly property real cellWidth: 80
    readonly property real gap: 11
    readonly property real wide: cellWidth * 2 + gap
    readonly property real full: cellWidth * 4 + gap * 3
    // A page's text sits about 26 px from every edge of the glass.
    readonly property real pagePadding: 15
    readonly property real pageTop: 17
    readonly property real pageBottom: 16
    // Match the inset of the round badges inside the grid's pills.
    readonly property real headerPadding: 14

    Glass {
        width: root.full + 28
        height: root.page === "" ? layout.implicitHeight + 28
            : pageHost.implicitHeight + root.pageTop + root.pageBottom
        radius: 26
        fillOpacity: Prefs.get("panelOpacity", Theme.opacity.panel)
        clip: false

        Behavior on height { NumberAnimation { duration: Motion.ms(240); easing.type: Easing.OutCubic } }

        // A page in place of the grid, sliding in from the right.
        Loader {
            id: pageHost
            x: root.pagePadding + (root.page !== "" ? 0 : 16)
            y: root.pageTop
            width: root.full + 28 - root.pagePadding * 2
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
            NetworkPage { maxHeight: root.maxPanelHeight - root.pageTop - root.pageBottom; onBack: root.back() }
        }
        Component {
            id: bluetoothPage
            BluetoothPage { maxHeight: root.maxPanelHeight - root.pageTop - root.pageBottom; onBack: root.back() }
        }
        Component {
            id: soundPage
            SoundPage { maxHeight: root.maxPanelHeight - root.pageTop - root.pageBottom; onBack: root.back() }
        }
        Component {
            id: mediaPage
            MediaPage { maxHeight: root.maxPanelHeight - root.pageTop - root.pageBottom; onBack: root.back(); onFinished: root.back() }
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

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: root.headerPadding
                    anchors.right: sessionActions.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    Label { width: parent.width; text: Theme.user.name; weight: Font.Bold; size: Theme.textSmall }
                    Label { width: parent.width; text: Session.uptime; dim: true; size: Theme.textSmall * 0.9 }
                }
                Row {
                    id: sessionActions
                    anchors.right: parent.right
                    anchors.rightMargin: root.headerPadding
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
                        // Niri's picker prints "Hex: #rrggbb" last; nothing is copied if it's cancelled.
                        Session.run(["sh", "-c", "sleep 0.3; c=$(niri msg pick-color | sed -n 's/^Hex: //p'); [ -n \"$c\" ] && printf %s \"$c\" | wl-copy"]);
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
