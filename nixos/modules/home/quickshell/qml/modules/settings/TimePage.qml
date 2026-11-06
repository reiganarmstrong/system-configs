import QtQuick
import qs.components.settings
import qs.services

Column {
    id: page
    required property var host
    readonly property var info: SettingsAdmin.get("time", {})
    property string zoneSearch: ""
    readonly property var zones: {
        const matches = (info.zones ?? []).filter(z => z.toLowerCase().includes(zoneSearch.toLowerCase())).slice(0, 80);
        return !zoneSearch && info.timezone && !matches.includes(info.timezone) ? [info.timezone, ...matches] : matches;
    }
    spacing: 10
    Component.onCompleted: SettingsAdmin.refresh("time")
    SettingRow {
        title: "Current time zone"
        detail: info.timezone ?? "Loading…"
    }
    SettingEntry {
        title: "Find a time zone"
        placeholder: "City or region"
        onTextChanged: page.zoneSearch = text
    }
    SettingChoice {
        title: "Time zone"
        detail: "Changing the system time zone may ask for your account password."
        options: page.zones
        value: page.info.timezone
        choiceWidth: 280
        enabled: !SettingsAdmin.mutating
        onChosen: v => SettingsAdmin.request("timezone", {
                zone: v
            })
    }
    SettingToggle {
        title: "24-hour clock"
        checked: Prefs.get("clock24h", false)
        onToggled: v => Prefs.set("clock24h", v)
    }
    SettingToggle {
        title: "Show seconds"
        checked: Prefs.get("showSeconds", false)
        onToggled: v => Prefs.set("showSeconds", v)
    }
    SettingRow {
        title: "Network time"
        detail: info.networkTime ? (info.synchronized ? "Enabled and synchronized" : "Enabled; waiting to synchronize") : "Not enabled"
    }
    SettingRow {
        title: "Language and regional formats"
        detail: (info.locale ?? "") + "\nThe system language and time synchronization policy are managed by the system configuration."
    }
    SettingAction {
        title: "Refresh time status"
        buttonText: "Refresh"
        onActivated: SettingsAdmin.refresh("time")
    }
}
