import QtQuick
import qs.components
import qs.components.settings
import qs.services

Column {
    id: page
    required property var host
    readonly property var info: SettingsAdmin.get("printers", {
        printers: [],
        jobs: []
    })
    property string queueName: ""
    property string printerUri: ""
    property string removeName: ""
    spacing: 10
    Component.onCompleted: SettingsAdmin.refresh("printers")
    SettingRow {
        visible: info.printers.length === 0
        title: "No printers configured"
        detail: "Add an IPP Everywhere network printer below, or use Advanced printer setup for USB and vendor-specific drivers."
    }
    Repeater {
        model: page.info.printers
        SettingRow {
            id: printer
            required property var modelData
            title: modelData.name
            detail: modelData.status + (page.info.default === modelData.name ? "\nYour default printer" : "")
            Row {
                spacing: 6
                SettingButton {
                    text: "Make default"
                    enabled: page.info.default !== printer.modelData.name && !SettingsAdmin.mutating
                    onClicked: SettingsAdmin.request("printer", {
                        operation: "default",
                        name: printer.modelData.name
                    })
                }
                SettingButton {
                    text: "Remove…"
                    enabled: !SettingsAdmin.mutating
                    onClicked: page.removeName = printer.modelData.name
                }
            }
        }
    }
    SettingRow {
        visible: page.removeName !== ""
        title: "Remove printer " + page.removeName + "?"
        Row {
            spacing: 8
            SettingButton {
                text: "Cancel"
                onClicked: page.removeName = ""
            }
            SettingButton {
                text: "Remove"
                destructive: true
                enabled: !SettingsAdmin.mutating
                onClicked: {
                    SettingsAdmin.request("printer", {
                        operation: "remove",
                        name: page.removeName
                    });
                    page.removeName = "";
                }
            }
        }
    }
    SectionLabel {
        text: "Your print queue"
    }
    Repeater {
        model: page.info.jobs
        SettingAction {
            required property var modelData
            title: modelData
            buttonText: "Cancel job"
            enabled: !SettingsAdmin.mutating
            onActivated: SettingsAdmin.request("printer", {
                operation: "cancel",
                job: modelData
            })
        }
    }
    SettingRow {
        visible: info.jobs.length === 0
        title: "No pending print jobs"
    }
    SectionLabel {
        text: "Add a network printer"
    }
    SettingEntry {
        title: "Printer name"
        placeholder: "Office_Printer"
        onTextChanged: page.queueName = text
    }
    SettingEntry {
        title: "Printer address"
        placeholder: "ipp://printer.local/ipp/print"
        onTextChanged: page.printerUri = text
        entryWidth: 280
    }
    SettingAction {
        title: "Add IPP Everywhere printer"
        detail: "Adding or removing a printer may ask for your account password. This uses the printer's driverless IPP interface."
        buttonText: "Add printer"
        enabled: page.queueName.trim() !== "" && page.printerUri.trim() !== "" && !SettingsAdmin.mutating
        onActivated: SettingsAdmin.request("printer", {
            operation: "add",
            name: page.queueName,
            uri: page.printerUri
        })
    }
    SettingAction {
        title: "Advanced printer setup"
        detail: "USB discovery, vendor drivers and advanced printer options."
        buttonText: "Open setup…"
        onActivated: host.launch(["system-config-printer"])
    }
    SettingAction {
        title: "Refresh printers"
        buttonText: "Refresh"
        onActivated: SettingsAdmin.refresh("printers")
    }
}
