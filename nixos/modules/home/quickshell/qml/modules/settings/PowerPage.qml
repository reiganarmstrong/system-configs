import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.components
import qs.components.settings
import qs.services

Column {
    required property var host
    spacing: 10
    SettingRow {
        title: "Battery"
        detail: Battery.present ? Math.round(Battery.level * 100) + "% · " + (Battery.charging ? "Charging" : "On battery") : "No battery detected on this machine."
    }
    SettingChoice {
        title: "Power mode"
        options: PowerProfiles.hasPerformanceProfile ? ["Power saver", "Balanced", "Performance"] : ["Power saver", "Balanced"]
        values: PowerProfiles.hasPerformanceProfile ? [0, 1, 2] : [0, 1]
        value: PowerProfiles.profile
        onChosen: v => PowerProfiles.profile = v
    }
    SettingToggle {
        title: "Keep awake"
        detail: "Caffeine pauses automatic locking, screen off and suspend."
        checked: Session.caffeine
        onToggled: v => Session.caffeine = v
    }
    SettingChoice {
        title: "Lock after inactivity"
        options: ["1 minute", "2 minutes", "5 minutes", "10 minutes", "15 minutes", "30 minutes", "60 minutes"]
        values: [1, 2, 5, 10, 15, 30, 60]
        value: host.pref("lockMinutes", 5)
        onChosen: v => {
            host.set("lockMinutes", v);
            if (v > host.pref("screenOffMinutes", 6))
                host.set("screenOffMinutes", v);
            if (host.pref("suspendMinutes", 0) > 0 && v > host.pref("suspendMinutes", 0))
                host.set("suspendMinutes", v);
        }
    }
    SettingChoice {
        title: "Turn screen off after"
        options: ["1 minute", "5 minutes", "6 minutes", "10 minutes", "15 minutes", "30 minutes", "60 minutes", "120 minutes"]
        values: [1, 5, 6, 10, 15, 30, 60, 120]
        value: host.pref("screenOffMinutes", 6)
        onChosen: v => {
            host.set("screenOffMinutes", v);
            if (v < host.pref("lockMinutes", 5))
                host.set("lockMinutes", v);
            if (host.pref("suspendMinutes", 0) > 0 && v > host.pref("suspendMinutes", 0))
                host.set("suspendMinutes", v);
        }
    }
    SettingChoice {
        title: "Suspend after"
        detail: Prefs.system.fixedDisplayMode ? "Keep this off for reliable remote access to the VM." : ""
        options: ["Never", "5 minutes", "15 minutes", "30 minutes", "60 minutes", "120 minutes"]
        values: [0, 5, 15, 30, 60, 120]
        value: host.pref("suspendMinutes", 0)
        onChosen: v => {
            host.set("suspendMinutes", v);
            if (v > 0 && v < host.pref("screenOffMinutes", 6)) {
                host.set("screenOffMinutes", v);
                if (v < host.pref("lockMinutes", 5))
                    host.set("lockMinutes", v);
            }
        }
    }
    SettingAction {
        title: "Lock screen"
        buttonText: "Lock"
        onActivated: Session.lock()
    }
    SettingRow {
        title: "Session"
        Row {
            spacing: 8
            SettingButton {
                text: "Log out"
                onClicked: host.confirmAction = "logout"
            }
            SettingButton {
                text: "Restart"
                onClicked: host.confirmAction = "reboot"
            }
            SettingButton {
                text: "Shut down"
                destructive: true
                onClicked: host.confirmAction = "poweroff"
            }
        }
    }
    SettingRow {
        visible: host.confirmAction !== ""
        title: "Confirm " + ({
                logout: "log out",
                reboot: "restart",
                poweroff: "shut down"
            })[host.confirmAction] + "?"
        Row {
            spacing: 8
            SettingButton {
                text: "Cancel"
                onClicked: host.confirmAction = ""
            }
            SettingButton {
                text: "Confirm"
                destructive: true
                onClicked: {
                    const action = host.confirmAction;
                    host.confirmAction = "";
                    Session[action]();
                }
            }
        }
    }
}
