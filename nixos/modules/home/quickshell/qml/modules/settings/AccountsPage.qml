import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.components
import qs.components.settings
import qs.services

Column {
    required property var host
    spacing: 10
    Component.onCompleted: SettingsAdmin.refresh("accounts")
    Repeater {
        model: SettingsAdmin.get("accounts", {
            online: []
        }).online
        SettingRow {
            required property var modelData
            title: modelData.provider
            detail: modelData.identity
        }
    }
    SettingRow {
        title: Theme.user.fullName
        detail: "User account: " + Theme.user.name
    }
    SettingAction {
        title: "Online accounts"
        detail: "Connect Google, Microsoft 365 / Outlook, and iCloud through WebDAV / CalDAV."
        onActivated: CalendarData.openAccounts()
    }
    SettingAction {
        title: "Calendars"
        detail: "Manage calendars, view events and create appointments."
        onActivated: CalendarData.openCalendar()
    }
    SettingRow {
        title: "Apple iCloud"
        detail: "In Online Accounts choose WebDAV. Use https://caldav.icloud.com/ with your Apple Account email and an app-specific password from account.apple.com."
    }
    SettingAction {
        title: "Passwords & keys"
        detail: "Manage saved passwords, login keyrings and encryption keys."
        onActivated: host.launch(["seahorse"])
    }
    SettingAction {
        title: "Account password"
        detail: Theme.data.mutablePassword ? "Change your login password in a terminal. Update your login keyring separately in Passwords & keys." : "This test VM uses a fixed account password."
        buttonText: "Change…"
        enabled: Theme.data.mutablePassword ?? false
        onActivated: host.launch(["ghostty", "-e", "passwd"])
    }
}
