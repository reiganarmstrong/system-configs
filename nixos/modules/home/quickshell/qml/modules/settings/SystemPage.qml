import QtQuick
import qs.components.settings
import qs.services

Column {
    required property var host
    property bool confirmingReset: false
    spacing: 10
    SettingRow {
        title: Prefs.system.hostname ?? "System"
        detail: (Prefs.system.os ?? "") + "\nKernel " + (Prefs.system.kernel ?? "") + "\n" + (Prefs.system.memoryGiB ?? "") + " GiB memory"
    }
    SettingRow {
        title: "Desktop"
        detail: "Niri with the shared Quickshell desktop. System packages and hardware support are maintained by the Nix configuration."
    }
    SettingAction {
        title: "Storage"
        detail: (Prefs.system.storageFreeGiB ?? "") + " GiB available of " + (Prefs.system.storageTotalGiB ?? "") + " GiB"
        buttonText: "Manage"
        onActivated: ShellState.openSettings("storage")
    }
    SettingAction {
        title: "Updates"
        buttonText: "Open"
        onActivated: ShellState.openSettings("updates")
    }
    SettingAction {
        title: "Reset desktop preferences"
        detail: "Restore appearance, input, notifications and lock timing. Confirmed monitor modes, applications and online accounts are preserved."
        buttonText: "Reset…"
        onActivated: confirmingReset = true
    }
    SettingRow {
        visible: confirmingReset
        title: "Restore default desktop preferences?"
        Row {
            spacing: 8
            SettingButton {
                text: "Cancel"
                onClicked: confirmingReset = false
            }
            SettingButton {
                text: "Reset"
                destructive: true
                onClicked: {
                    Prefs.reset();
                    confirmingReset = false;
                }
            }
        }
    }
}
