// The top bar: a solid black strip across the output. Numbered workspaces on
// the left, the clock alone in the middle, status icons on the right.
import QtQuick
import Quickshell
import Quickshell.Wayland
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
    implicitHeight: Theme.barHeight
    color: Theme.barFill

    // The control centre's Caffeine keeps the screen awake through this.
    // It's attached to the bar only while Caffeine is on: an attached but
    // disabled IdleInhibitor still blocks idle in Quickshell 0.3.0.
    IdleInhibitor {
        window: Session.caffeine ? bar : null
        enabled: Session.caffeine
    }

    // One status icon. Each toggles its own popup: a StatusMenu for Wi-Fi,
    // Bluetooth and Sound, or the control centre.
    component StatusButton: Pill {
        id: button
        property string icon
        property string menu: "control"
        property string tip
        clickable: true
        padding: 7
        onClicked: ShellState.toggle(menu)
        Accessible.role: Accessible.Button
        Accessible.name: tip
        Accessible.onPressAction: ShellState.toggle(menu)
        BarTip { parent: button; visible: button.hovered; text: button.tip }
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: button.icon
        }
    }

    // Workspaces: a round grey pill per occupied workspace; the active one is
    // white, half again as wide, with dark numerals.
    Row {
        id: workspaces
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Repeater {
            model: Compositor.workspacesOn(bar.screen?.name ?? "")

            Rectangle {
                id: ws
                required property var modelData
                readonly property bool current: modelData.is_active

                anchors.verticalCenter: parent.verticalCenter
                height: 18
                width: current ? 27 : 18
                radius: height / 2
                color: current ? "#f2f2f3"
                    : modelData.is_urgent ? Theme.colors.urgent
                    : area.containsMouse && ShellState.openPanel === "" ? "#4a4a50"
                    : modelData.active_window_id !== null ? "#3a3a3f" : "#26262a"
                Accessible.role: Accessible.Button
                Accessible.name: "Workspace " + label.text

                Behavior on width {
                    NumberAnimation { duration: Motion.ms(180); easing.type: Easing.OutCubic }
                }
                Behavior on color {
                    ColorAnimation { duration: Motion.ms(140) }
                }

                Label {
                    id: label
                    anchors.centerIn: parent
                    text: ws.modelData.name ?? ws.modelData.idx
                    size: Theme.textSmall
                    weight: Font.DemiBold
                    color: ws.current || ws.modelData.is_urgent ? Theme.colors.accentText : "#ececee"
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Compositor.focusWorkspace(ws.modelData.id)
                }
            }
        }
    }

    // The time alone, centred on the output; opens the calendar and
    // notification centre. The date is in its tooltip.
    Pill {
        id: clockPill
        anchors.centerIn: parent
        padding: 10
        clickable: true
        onClicked: ShellState.toggle("dash")
        Accessible.role: Accessible.Button
        Accessible.name: "Calendar and notifications"
        Accessible.onPressAction: ShellState.toggle("dash")
        BarTip {
            parent: clockPill
            visible: clockPill.hovered
            text: Qt.formatDate(clock.date, "dddd, MMMM d")
        }

        SystemClock {
            id: clock
            precision: Prefs.get("showSeconds", false) ? SystemClock.Seconds : SystemClock.Minutes
        }

        Label {
            weight: Font.DemiBold
            font.features: ({ "tnum": 1 })
            text: Qt.formatTime(clock.date,
                (Prefs.get("clock24h", false) ? "HH:mm" : "h:mm")
                + (Prefs.get("showSeconds", false) ? ":ss" : "")
                + (Prefs.get("clock24h", false) ? "" : " AP"))
        }
    }

    // Status icons, each with its own hover target.
    Row {
        id: status
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        // Clipboard history has its own popup, separate from Control Center.
        Pill {
            id: clipboardPill
            anchors.verticalCenter: parent.verticalCenter
            clickable: true
            padding: 7
            onClicked: ShellState.toggle("clipboard")
            Accessible.role: Accessible.Button
            Accessible.name: "Clipboard history"
            Accessible.onPressAction: ShellState.toggle("clipboard")
            BarTip { parent: clipboardPill; visible: clipboardPill.hovered; text: "Clipboard history · Super+Shift+V" }
            Icon { anchors.verticalCenter: parent.verticalCenter; name: "clipboard-list" }
        }

        StatusButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: Net.icon
            menu: "network"
            tip: "Network"
        }
        StatusButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: Bt.available
            icon: !Bt.enabled ? "bluetooth-off" : Bt.connected.length > 0 ? "bluetooth-connected" : "bluetooth"
            menu: "bluetooth"
            tip: "Bluetooth"
        }
        StatusButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: Audio.icon
            menu: "sound"
            tip: "Sound"
        }

        // Battery, with its percentage; opens the control centre's grid.
        Pill {
            anchors.verticalCenter: parent.verticalCenter
            visible: Battery.present
            clickable: true
            padding: 7
            spacing: 5
            onClicked: ShellState.toggle("control")
            Accessible.role: Accessible.Button
            Accessible.name: "Battery " + Math.round(Battery.level * 100) + "%"
            Accessible.onPressAction: ShellState.toggle("control")
            Icon { anchors.verticalCenter: parent.verticalCenter; name: Battery.icon; size: 17 }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                size: Theme.textSmall
                weight: Font.DemiBold
                font.features: ({ "tnum": 1 })
                text: Math.round(Battery.level * 100) + "%"
                visible: Prefs.get("showBatteryPercent", true)
            }
        }

        // Without a battery, a settings-free way into the control centre grid.
        StatusButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: !Battery.present
            icon: "sliders-horizontal"
            tip: "Control centre"
        }
    }
}
