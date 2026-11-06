import QtQuick
import Quickshell
import qs.components.settings
import qs.services

Column {
    id: page
    required property var host
    property string filter: ""
    readonly property var enabledApps: SettingsAdmin.get("apps", {
        startup: []
    }).startup
    readonly property var apps: DesktopEntries.applications.values.filter(a => !a.noDisplay && a.name.toLowerCase().includes(filter.toLowerCase())).sort((a, b) => a.name.localeCompare(b.name))
    spacing: 10
    Component.onCompleted: SettingsAdmin.refresh("apps")
    SettingRow {
        title: "Open apps when you sign in"
        detail: "Selected applications start once per desktop login. Restarting the desktop shell does not start them again."
    }
    SettingEntry {
        title: "Find an application"
        placeholder: "Application name"
        onTextChanged: page.filter = text
    }
    Repeater {
        model: page.apps
        SettingToggle {
            required property var modelData
            title: modelData.name
            checked: page.enabledApps.includes(modelData.id)
            enabled: !SettingsAdmin.mutating
            onToggled: value => SettingsAdmin.request("startup", {
                    id: modelData.id,
                    enabled: value
                })
        }
    }
    Repeater {
        model: page.enabledApps.filter(id => !DesktopEntries.applications.values.some(a => !a.noDisplay && a.id === id))
        SettingAction {
            required property var modelData
            title: modelData
            detail: "This entry is unavailable or hidden."
            buttonText: "Remove"
            onActivated: SettingsAdmin.request("startup", {
                id: modelData,
                enabled: false
            })
        }
    }
}
