import QtQuick
import qs.components
import qs.components.settings
import qs.services

Column {
    id: page
    required property var host
    readonly property var info: SettingsAdmin.get("storage", {
        volumes: [],
        drives: []
    })
    property bool emptyConfirmed: false
    spacing: 10
    Component.onCompleted: SettingsAdmin.refresh("storage")
    SettingRow {
        title: "Home storage"
        detail: (info.freeGiB ?? "…") + " GiB available of " + (info.totalGiB ?? "…") + " GiB"
    }
    SectionLabel {
        text: "Volumes"
    }
    Repeater {
        model: page.info.volumes
        SettingRow {
            id: volume
            required property var modelData
            title: modelData.name
            detail: modelData.device + " · " + modelData.sizeGiB + " GiB · " + modelData.filesystem + (modelData.mounts.length ? "\n" + modelData.mounts.join(", ") : "\nNot mounted") + (modelData.protected ? "\nSystem or home volume" : "")
            Row {
                spacing: 6
                SettingButton {
                    text: "Open"
                    visible: volume.modelData.mounts.length > 0
                    onClicked: host.launch(["nautilus", "--new-window", volume.modelData.mounts[0]])
                }
                SettingButton {
                    text: volume.modelData.mounts.length ? "Unmount" : "Mount"
                    visible: !volume.modelData.protected
                    enabled: !SettingsAdmin.mutating
                    onClicked: SettingsAdmin.request("storage", {
                        operation: volume.modelData.mounts.length ? "unmount" : "mount",
                        device: volume.modelData.device
                    })
                }
            }
        }
    }
    Repeater {
        // Empty card readers and floppy slots report removable drives of size 0.
        model: page.info.drives.filter(d => d.removable && !d.protected && d.sizeGiB > 0)
        SettingAction {
            required property var modelData
            title: modelData.name
            detail: "Unmount its volumes before disconnecting this drive."
            buttonText: "Eject"
            enabled: !SettingsAdmin.mutating
            onActivated: SettingsAdmin.request("storage", {
                operation: "eject",
                device: modelData.device
            })
        }
    }
    SectionLabel {
        text: "Trash"
    }
    SettingAction {
        title: "Empty Trash"
        detail: (info.trashCount ?? 0) ? info.trashCount + (info.trashCount === 1 ? " deleted item" : " deleted items") + " in your home Trash. Emptying permanently removes deleted files." : "Your home Trash is empty."
        buttonText: "Empty…"
        enabled: (info.trashCount ?? 0) > 0
        onActivated: page.emptyConfirmed = true
    }
    SettingRow {
        visible: page.emptyConfirmed && (info.trashCount ?? 0) > 0
        title: "Permanently delete the files in Trash?"
        Row {
            spacing: 8
            SettingButton {
                text: "Cancel"
                onClicked: page.emptyConfirmed = false
            }
            SettingButton {
                text: "Empty Trash"
                destructive: true
                enabled: !SettingsAdmin.mutating
                onClicked: {
                    SettingsAdmin.request("empty-trash", {});
                    page.emptyConfirmed = false;
                }
            }
        }
    }
    SettingAction {
        title: "Partitions, encryption and disk diagnostics"
        detail: "Advanced disk operations use the maintained Disks application."
        buttonText: "Open Disks…"
        onActivated: host.launch(["gnome-disks"])
    }
    SettingAction {
        title: "Refresh storage"
        buttonText: "Refresh"
        onActivated: SettingsAdmin.refresh("storage")
    }
}
