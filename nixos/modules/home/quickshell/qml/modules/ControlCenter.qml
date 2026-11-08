// The control centre, dropping from the bar's battery icon or Super+S. Laid out on a grid of
// cells like macOS: capsule toggles span two columns, small toggles one,
// now playing two rows, and the sliders the full width. Wi-Fi,
// Bluetooth, Sound and Now Playing open detail pages that replace the grid
// inside the same panel.
import QtQuick
import QtQuick.Layouts
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
    // Keep the current page and panel height through the closing fade, and
    // unload it afterwards, which stops the page's scanning.
    onOpenChanged: if (open) resetPage()
    onVisibleChanged: if (!visible) resetPage()

    // The panel is a 4-column grid: capsule toggles span two columns, small
    // toggles one, Now Playing two rows, and the sliders all four. The grid
    // and pages share Theme.spacing.panel at the sides and top; the grid
    // has Theme.bottomPadding below it, matching the space under a page's
    // footer text.
    readonly property real padding: Theme.spacing.panel
    readonly property real gap: Theme.spacing.tile
    readonly property real panelWidth: Theme.menuWidth
    readonly property real contentWidth: panelWidth - padding * 2
    readonly property real cell: 66
    readonly property real cellWidth: (contentWidth - gap * 3) / 4
    // Width of a tile spanning n columns. The grid places tiles by their
    // spans; this keeps its four columns equal whatever each tile asks for.
    function span(n: int): real {
        return cellWidth * n + gap * (n - 1);
    }
    // Match the inset of the round badges inside the grid's pills.
    readonly property real headerPadding: 14

    Glass {
        width: root.panelWidth
        height: root.page === "" ? layout.implicitHeight + root.padding + Theme.bottomPadding
            : pageHost.implicitHeight + root.padding * 2
        radius: 26
        fillOpacity: Prefs.get("panelOpacity", Theme.opacity.panel)
        clip: false

        Behavior on height { NumberAnimation { duration: Motion.ms(240); easing.type: Easing.OutCubic } }

        // A page in place of the grid, sliding in from the right.
        Loader {
            id: pageHost
            x: root.padding + (root.page !== "" ? 0 : 16)
            y: root.padding
            width: root.contentWidth
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
            NetworkPage { maxHeight: root.maxPanelHeight - root.padding * 2; onBack: root.back() }
        }
        Component {
            id: bluetoothPage
            BluetoothPage { maxHeight: root.maxPanelHeight - root.padding * 2; onBack: root.back() }
        }
        Component {
            id: soundPage
            SoundPage { maxHeight: root.maxPanelHeight - root.padding * 2; onBack: root.back() }
        }
        Component {
            id: mediaPage
            MediaPage { maxHeight: root.maxPanelHeight - root.padding * 2; onBack: root.back(); onFinished: root.back() }
        }

        GridLayout {
            id: layout
            x: root.padding + (root.page === "" ? 0 : -12)
            y: root.padding
            width: root.contentWidth
            columns: 4
            columnSpacing: root.gap
            rowSpacing: root.gap
            opacity: root.page === "" ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: Motion.ms(root.page === "" ? 180 : 120); easing.type: Easing.OutCubic }
            }
            Behavior on x {
                NumberAnimation { duration: Motion.ms(root.page === "" ? 180 : 120); easing.type: Easing.OutCubic }
            }

            // Who is logged in, and the session buttons.
            RowLayout {
                Layout.columnSpan: 4
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                Layout.leftMargin: root.headerPadding
                Layout.rightMargin: root.headerPadding
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0
                    Label { Layout.fillWidth: true; text: Theme.user.name; weight: Font.Bold; size: Theme.textSmall }
                    Label { Layout.fillWidth: true; text: Session.uptime; dim: true; size: Theme.textSmall * 0.9 }
                }
                RowLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 4

                    Repeater {
                        model: [
                            { icon: "settings", run: () => ShellState.openSettings("appearance") },
                            { icon: "lock", run: () => Session.lock() },
                            { icon: "moon", enabled: Theme.data.suspendSupported !== false, run: () => Session.suspend() },
                            { icon: "log-out", run: () => Session.logout() },
                            { icon: "rotate-ccw", run: () => Session.reboot() },
                            { icon: "power", run: () => Session.poweroff() },
                        ]
                        Rectangle {
                            required property var modelData
                            enabled: modelData.enabled ?? true
                            opacity: enabled ? 1 : 0.35
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
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

            // Wi-Fi above Bluetooth, beside Now Playing.
            PillToggle {
                Layout.columnSpan: 2
                Layout.preferredWidth: root.span(2)
                Layout.preferredHeight: root.cell
                icon: Net.icon
                title: Net.title
                subtitle: Net.status
                active: Net.wiredUp || Net.wifiUp
                openable: true
                onToggled: if (Net.wifi) Net.setWifi(!Net.wifiOn)
                onOpened: root.openPage("network")
            }
            MediaCard {
                Layout.columnSpan: 2
                Layout.rowSpan: 2
                Layout.preferredWidth: root.span(2)
                Layout.fillHeight: true
                onOpened: root.openPage("media")
            }
            PillToggle {
                Layout.columnSpan: 2
                Layout.preferredWidth: root.span(2)
                Layout.preferredHeight: root.cell
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

            // Focus with Airplane Mode and Caffeine.
            PillToggle {
                Layout.columnSpan: 2
                Layout.preferredWidth: root.span(2)
                Layout.preferredHeight: root.cell
                icon: Notifs.doNotDisturb ? "bell-off" : "bell"
                title: "Focus"
                subtitle: Notifs.doNotDisturb ? "Do Not Disturb" : "Off"
                active: Notifs.doNotDisturb
                onClicked: Prefs.set("doNotDisturb", !Notifs.doNotDisturb)
            }
            CircleToggle {
                Layout.preferredWidth: root.span(1)
                Layout.preferredHeight: root.cell
                readonly property bool airplane: !Net.wifiOn && !Bt.enabled
                icon: "plane"
                active: airplane
                enabled: Net.wifi !== null || Bt.available
                opacity: enabled ? 1 : 0.5
                onClicked: {
                    const enableRadios = airplane;
                    Net.setWifi(enableRadios);
                    Bt.setEnabled(enableRadios);
                }
            }
            CircleToggle {
                Layout.preferredWidth: root.span(1)
                Layout.preferredHeight: root.cell
                icon: "coffee"
                active: Session.caffeine
                onClicked: Session.caffeine = !Session.caffeine
            }

            // Power with the microphone and colour picker. The icon follows
            // the profile: leaf, gauge or bolt.
            PillToggle {
                readonly property var names: ["Power Saver", "Balanced", "Performance"]
                Layout.columnSpan: 2
                Layout.preferredWidth: root.span(2)
                Layout.preferredHeight: root.cell
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
                Layout.preferredWidth: root.span(1)
                Layout.preferredHeight: root.cell
                icon: Audio.micMuted ? "mic-off" : "mic"
                active: !Audio.micMuted
                onClicked: Audio.toggleMic()
            }
            CircleToggle {
                Layout.preferredWidth: root.span(1)
                Layout.preferredHeight: root.cell
                icon: "pipette"
                onClicked: {
                    ShellState.close();
                    // Niri's picker prints "Hex: #rrggbb" last; nothing is copied if it's cancelled.
                    Session.run(["sh", "-c", "sleep 0.3; c=$(niri msg pick-color | sed -n 's/^Hex: //p'); [ -n \"$c\" ] && printf %s \"$c\" | wl-copy"]);
                }
            }

            SliderTile {
                Layout.columnSpan: 4
                Layout.preferredWidth: root.span(4)
                title: "Display"
                onTitleClicked: ShellState.openSettings("display")
                detail: Brightness.available ? "" : "Not adjustable"
                sliderEnabled: Brightness.available
                startIcon: "sun-dim"
                endIcon: "sun"
                value: Brightness.level
                onMoved: v => Brightness.set(v)
            }

            SliderTile {
                Layout.columnSpan: 4
                Layout.preferredWidth: root.span(4)
                title: "Sound"
                openable: true
                onOpened: root.openPage("sound")
                detail: Audio.sinkName
                sliderEnabled: Audio.sink !== null
                startIcon: "volume"
                endIcon: "volume-2"
                value: Audio.muted ? 0 : Audio.volume
                onMoved: v => Audio.setVolume(v)
                onStartIconClicked: Audio.toggleMute()
            }
        }
    }
}
