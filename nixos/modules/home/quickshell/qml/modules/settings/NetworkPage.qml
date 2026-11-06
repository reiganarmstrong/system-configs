import QtQuick
import qs.components
import qs.components.settings
import qs.modules.cc as Radio
import qs.services

Column {
    required property var host
    readonly property var info: SettingsAdmin.get("network", {})
    spacing: 10
    Component.onCompleted: SettingsAdmin.refresh("network")
    function handleEscape(): bool {
        return networks.handleEscape();
    }
    SettingRow {
        title: Net.title
        detail: Net.status + (Prefs.system.ip ? "\n" + Prefs.system.ip : "")
    }
    SettingToggle {
        title: "Airplane mode"
        detail: "Turn off Wi-Fi and Bluetooth radios."
        enabled: Net.wifi !== null || Bt.available
        checked: !Net.wifiOn && !Bt.enabled
        onToggled: v => {
            Net.setWifi(!v);
            Bt.setEnabled(!v);
        }
    }
    Radio.NetworkPage {
        id: networks
        showBack: false
        scrolls: false
        footerText: ""
        configureEnterprise: () => Session.run(["nm-connection-editor", "--create", "--type", "802-11-wireless"])
    }
    SectionLabel {
        text: "VPN"
    }
    Repeater {
        model: info.profiles ?? []
        SettingToggle {
            required property var modelData
            title: modelData.name
            detail: modelData.active ? "Connected" : "Not connected"
            checked: modelData.active
            enabled: !SettingsAdmin.mutating
            onToggled: value => SettingsAdmin.request("network-profile", {
                    uuid: modelData.uuid,
                    enabled: value
                })
        }
    }
    SettingRow {
        visible: (info.profiles ?? []).length === 0
        title: "No saved VPN connections"
        detail: "Add a VPN profile using Advanced connections, then connect from here."
    }
    SettingAction {
        title: "Advanced connections"
        detail: "Edit Ethernet, DNS, proxies, VPN profiles and enterprise Wi-Fi in the connection editor."
        buttonText: "Open editor…"
        onActivated: host.launch(["nm-connection-editor"])
    }
    SectionLabel {
        text: "Tailscale"
    }
    SettingRow {
        title: info.name || "Private network"
        detail: (info.state ?? "Loading…") + ((info.addresses ?? []).length ? "\n" + info.addresses.join(" · ") : "")
    }
    SettingToggle {
        title: "Connected to Tailscale"
        enabled: ["Running", "Stopped"].includes(info.state) && !SettingsAdmin.mutating
        checked: info.state === "Running"
        onToggled: v => SettingsAdmin.request("tailscale", {
                enabled: v
            })
    }
    SettingAction {
        visible: info.state === "NeedsLogin"
        title: "Sign in to Tailscale"
        detail: "One-time account authorization uses Tailscale's own sign-in flow."
        buttonText: "Sign in…"
        onActivated: host.launch(["ghostty", "-e", "tailscale", "up"])
    }
    SettingAction {
        title: "Refresh network status"
        buttonText: "Refresh"
        onActivated: {
            SettingsAdmin.refresh("network");
            Prefs.refresh();
        }
    }
}
