import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.components
import qs.components.settings
import qs.services

Column {
    required property var host
    spacing: 10
    SettingToggle {
        title: "Do Not Disturb"
        detail: "Send notifications to history. Critical alerts still appear."
        checked: Notifs.doNotDisturb
        onToggled: v => host.set("doNotDisturb", v)
    }
    SettingChoice {
        title: "Banner duration"
        options: ["3 seconds", "6 seconds", "8 seconds", "12 seconds", "Until dismissed"]
        values: [3, 6, 8, 12, 0]
        value: host.pref("bannerSeconds", 6)
        onChosen: v => host.set("bannerSeconds", v)
    }
    SettingAction {
        title: "Notification history"
        detail: Notifs.history.length + " notifications"
        buttonText: "Open"
        onActivated: {
            ShellState.settingsOpen = false;
            ShellState.toggle("dash");
        }
    }
    SettingAction {
        title: "Clear history"
        enabled: Notifs.history.length > 0
        buttonText: "Clear"
        onActivated: Notifs.clearAll()
    }
}
