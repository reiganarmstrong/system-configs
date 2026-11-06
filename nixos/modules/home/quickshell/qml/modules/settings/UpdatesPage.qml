import QtQuick
import qs.components
import qs.components.settings
import qs.services

Column {
    id: page
    required property var host
    readonly property var info: SettingsAdmin.get("updates", {})
    function describe(unit) {
        if (!unit || unit.LoadState === "not-found")
            return "Not scheduled on this machine";
        if (["activating", "deactivating"].includes(unit.ActiveState))
            return "Working in the background…";
        if (unit.ActiveState === "failed")
            return "Last run failed (" + (unit.Result || "error") + ")" + (unit.StateChangeTimestamp ? "\n" + unit.StateChangeTimestamp : "");
        // systemd reports Result=success for a unit that has not run since boot.
        if (!unit.StateChangeTimestamp)
            return "Not run since startup";
        return (unit.Result === "success" ? "Last run succeeded" : "Last run: " + unit.Result) + "\n" + unit.StateChangeTimestamp;
    }
    spacing: 10
    Component.onCompleted: SettingsAdmin.refresh("updates")
    Timer {
        // Poll quickly only while a job runs.
        interval: [info.system, info.apps, info.userApps].some(u => ["activating", "deactivating"].includes(u?.ActiveState)) ? 3000 : 15000
        repeat: true
        running: true
        onTriggered: SettingsAdmin.refresh("updates")
    }
    SettingRow {
        title: info.rebootRequired ? "Restart to finish the system update" : "System updates"
        detail: info.systemEnabled ? "Updates are prepared from your configuration repository and take effect at the next boot. The machine never restarts automatically.\n" + (info.source ?? "") : "This test VM receives system updates when its VM configuration is rebuilt. App updates are available below."
    }
    SettingAction {
        title: "Prepare system update"
        detail: page.describe(info.system)
        buttonText: "Prepare update"
        enabled: info.systemEnabled === true && !SettingsAdmin.mutating && info.system?.ActiveState !== "activating"
        onActivated: SettingsAdmin.request("update", {
            kind: "system"
        })
    }
    SettingAction {
        title: "System Flatpak apps"
        detail: page.describe(info.apps)
        buttonText: "Update apps"
        enabled: !SettingsAdmin.mutating && info.apps?.ActiveState !== "activating"
        onActivated: SettingsAdmin.request("update", {
            kind: "system-apps"
        })
    }
    SettingAction {
        title: "Apps added for your account"
        detail: page.describe(info.userApps)
        buttonText: "Update apps"
        enabled: !SettingsAdmin.mutating && info.userApps?.ActiveState !== "activating"
        onActivated: SettingsAdmin.request("update", {
            kind: "user-apps"
        })
    }
    SettingRow {
        title: "Rollback"
        detail: "Recent system generations remain available in the laptop's boot menu. App and user-data changes have their own lifecycle."
    }
    SettingAction {
        title: "Refresh update status"
        buttonText: "Refresh"
        onActivated: SettingsAdmin.refresh("updates")
    }
}
