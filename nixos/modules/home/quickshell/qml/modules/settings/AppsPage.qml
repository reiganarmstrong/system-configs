import QtQuick
import Quickshell
import qs.components
import qs.components.settings
import qs.services

Column {
    id: page
    required property var host
    property string filter: ""
    property string storeQuery: SettingsAdmin.get("appSearch", {
        query: ""
    }).query
    // Confirmations and details open inside the row that asked for them.
    property string removeId: ""
    property string selectedId: ""
    property bool confirmPermissions: false
    readonly property var info: SettingsAdmin.get("apps", {
        installed: [],
        jobs: []
    })
    readonly property var search: SettingsAdmin.get("appSearch", {
        query: "",
        items: []
    })
    readonly property var detail: SettingsAdmin.get("appDetail", {})
    readonly property var entries: {
        const visible = DesktopEntries.applications.values.filter(a => !a.noDisplay);
        const result = visible.map(a => ({
                    id: a.id,
                    name: a.name,
                    entry: a,
                    flatpak: info.installed.find(f => f.id === a.id) ?? null
                }));
        for (const f of info.installed)
            if (!result.some(a => a.id === f.id))
                result.push({
                    id: f.id,
                    name: f.name,
                    entry: null,
                    flatpak: f
                });
        return result.filter(a => a.name.toLowerCase().includes(filter.toLowerCase())).sort((a, b) => a.name.localeCompare(b.name));
    }
    // Install and remove jobs that are running or failed; update jobs are on Updates.
    readonly property var operations: (info.jobs ?? []).filter(j => j.operation !== "update" && ["activating", "deactivating", "failed"].includes(j.ActiveState))
    function appName(id: string): string {
        return (info.installed.find(a => a.id === id) ?? search.items.find(a => a.id === id) ?? DesktopEntries.byId(id))?.name ?? id;
    }
    spacing: 10
    Component.onCompleted: SettingsAdmin.refresh("apps")
    Timer {
        interval: 2000
        repeat: true
        running: (page.info.jobs ?? []).some(j => ["activating", "deactivating"].includes(j.ActiveState))
        onTriggered: SettingsAdmin.refresh("apps")
    }
    Repeater {
        model: page.operations
        SettingRow {
            id: job
            required property var modelData
            readonly property bool failed: modelData.ActiveState === "failed"
            readonly property string name: page.appName(modelData.app)
            title: failed ? (modelData.operation === "install" ? "Couldn’t install " : "Couldn’t remove ") + name : (modelData.operation === "install" ? "Installing " : "Removing ") + name + "…"
            detail: failed ? (modelData.log ? modelData.log.trim().split("\n").slice(-2).join("\n") : "The operation stopped with an error.") + "\nFull log: journalctl --user -u " + modelData.unit : "Working in the background. You can close Settings."
            Row {
                spacing: 6
                visible: job.failed
                SettingButton {
                    text: "Retry"
                    enabled: !SettingsAdmin.mutating
                    onClicked: SettingsAdmin.request(job.modelData.operation === "install" ? "app-install" : "app-remove", {
                        id: job.modelData.app
                    })
                }
                SettingButton {
                    text: "Dismiss"
                    enabled: !SettingsAdmin.mutating
                    onClicked: SettingsAdmin.request("app-job-dismiss", {
                        unit: job.modelData.unit
                    })
                }
            }
        }
    }
    SectionLabel {
        text: "Add applications"
    }
    SettingEntry {
        title: "Search Flathub"
        text: page.storeQuery
        placeholder: "Application name"
        onTextChanged: page.storeQuery = text
        onAccepted: if (text.trim())
            SettingsAdmin.request("app-search", {
                query: text
            })
    }
    SettingAction {
        title: "Find applications"
        detail: "Additional apps install for your account. System-managed apps remain installed by the configuration."
        buttonText: "Search"
        enabled: page.storeQuery.trim().length > 0 && !SettingsAdmin.mutating
        onActivated: SettingsAdmin.request("app-search", {
            query: page.storeQuery
        })
    }
    Repeater {
        model: page.search.items
        SettingAction {
            required property var modelData
            title: modelData.name
            detail: modelData.description
            readonly property bool installed: page.info.installed.some(a => a.id === modelData.id)
            readonly property bool working: page.operations.some(j => j.app === modelData.id && j.ActiveState !== "failed")
            buttonText: installed ? "Installed" : working ? "Installing…" : "Install"
            enabled: !installed && !working && !SettingsAdmin.mutating
            onActivated: SettingsAdmin.request("app-install", {
                id: modelData.id
            })
        }
    }
    SettingRow {
        visible: page.search.query !== "" && page.search.items.length === 0
        title: "No applications found"
        detail: "Try another name or check the spelling."
    }
    SectionLabel {
        text: "Installed applications"
    }
    SettingEntry {
        title: "Find installed apps"
        placeholder: "Application name"
        onTextChanged: page.filter = text
    }
    Repeater {
        model: page.entries
        Column {
            id: appRow
            required property var modelData
            readonly property bool removing: page.removeId === modelData.id
            readonly property bool inspecting: page.selectedId === modelData.id
            readonly property bool loaded: inspecting && page.detail.id === modelData.id
            width: parent.width
            spacing: 6
            SettingRow {
                title: appRow.modelData.name
                detail: appRow.modelData.flatpak ? "Flatpak · " + (appRow.modelData.flatpak.version || "Installed") + (appRow.modelData.flatpak.scope === "system" ? " · System installation" : " · Your account") : "Managed by the system configuration"
                Row {
                    spacing: 6
                    SettingButton {
                        text: "Open"
                        enabled: appRow.modelData.entry !== null || appRow.modelData.flatpak !== null
                        onClicked: appRow.modelData.entry ? AppLaunch.launch(appRow.modelData.entry) : SettingsAdmin.request("app-open", {
                            id: appRow.modelData.id,
                            scope: appRow.modelData.flatpak.scope
                        })
                    }
                    SettingButton {
                        text: appRow.inspecting ? "Hide permissions" : "Permissions"
                        visible: appRow.modelData.flatpak !== null
                        onClicked: {
                            page.confirmPermissions = false;
                            if (appRow.inspecting) {
                                page.selectedId = "";
                                return;
                            }
                            page.selectedId = appRow.modelData.id;
                            SettingsAdmin.request("app-detail", {
                                id: appRow.modelData.id,
                                scope: appRow.modelData.flatpak.scope
                            });
                        }
                    }
                    SettingButton {
                        text: "Remove…"
                        visible: appRow.modelData.flatpak?.scope === "user"
                        enabled: !SettingsAdmin.mutating
                        onClicked: page.removeId = appRow.modelData.id
                    }
                }
            }
            SettingRow {
                visible: appRow.removing
                title: "Remove " + appRow.modelData.name + "?"
                detail: "The app is removed from your account. Its saved data is kept."
                Row {
                    spacing: 8
                    SettingButton {
                        text: "Cancel"
                        onClicked: page.removeId = ""
                    }
                    SettingButton {
                        text: "Remove"
                        destructive: true
                        enabled: !SettingsAdmin.mutating
                        onClicked: {
                            SettingsAdmin.request("app-remove", {
                                id: appRow.modelData.id
                            });
                            page.removeId = "";
                        }
                    }
                }
            }
            SettingRow {
                visible: appRow.inspecting
                title: "Permissions"
                detail: !appRow.loaded ? "Loading…" : (page.detail.network ? "Network access allowed" : "No direct network access") + "\nFiles: " + ((page.detail.filesystems ?? []).join(", ") || "Only files selected through a portal") + "\nDevices: " + ((page.detail.devices ?? []).join(", ") || "No direct device access")
            }
            SettingAction {
                visible: appRow.loaded
                title: "Reset permission overrides"
                detail: "Remove overrides you added for this account. The app's packaged permissions remain. Restart the app afterwards."
                buttonText: "Reset…"
                onActivated: page.confirmPermissions = true
            }
            SettingRow {
                visible: appRow.loaded && page.confirmPermissions
                title: "Restore the packaged permissions of " + appRow.modelData.name + "?"
                Row {
                    spacing: 8
                    SettingButton {
                        text: "Cancel"
                        onClicked: page.confirmPermissions = false
                    }
                    SettingButton {
                        text: "Reset"
                        enabled: !SettingsAdmin.mutating
                        onClicked: {
                            SettingsAdmin.request("app-reset-permissions", {
                                id: page.detail.id,
                                scope: page.detail.scope
                            });
                            page.confirmPermissions = false;
                        }
                    }
                }
            }
        }
    }
    SettingAction {
        title: "Refresh application list"
        buttonText: "Refresh"
        onActivated: SettingsAdmin.refresh("apps")
    }
}
