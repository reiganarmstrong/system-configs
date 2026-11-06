// Wi-Fi and Ethernet, like macOS: known networks, then others found by a
// scan that runs only while this page is open. Secured networks ask for
// their password inline.
import QtQuick
import Quickshell
import Quickshell.Networking
import qs.components
import qs.services

SubPanel {
    id: page

    property var configureEnterprise: () => ShellState.openSettings("network")

    title: Net.wifi ? "Wi-Fi" : "Network"
    showSwitch: Net.wifi !== null
    checked: Net.wifiOn
    switchEnabled: Net.hardwareEnabled
    footerText: "Network Settings…"
    onSwitchToggled: on => Net.setWifi(on)
    onFooterClicked: ShellState.openSettings("network")

    // The network whose password row is open, and its state.
    property var passwordFor: null
    property string passwordError: ""
    property bool joining: false
    // The last password join: which network, whether it was new (a failed
    // new join is forgotten again, so a wrong password isn't saved), and
    // when. The row is recreated when the network moves between sections,
    // so this lives on the page.
    property var attempt: null
    // Short-lived "Couldn't connect" messages, by network name.
    property var failures: ({})
    property bool justOpened: true

    readonly property var networks: {
        if (!Net.wifi || !Net.wifiOn)
            return [];
        const byName = {};
        for (const n of Net.wifi.networks.values) {
            if (!n.name)
                continue;
            if (!byName[n.name] || n.signalStrength > byName[n.name].signalStrength)
                byName[n.name] = n;
        }
        return Object.values(byName).sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength));
    }
    readonly property var known: networks.filter(n => n.known || n.connected)
    readonly property var others: networks.filter(n => !n.known && !n.connected)

    // Escape closes an open password row before going back.
    function handleEscape(): bool {
        if (passwordFor) {
            closePassword();
            return true;
        }
        return false;
    }
    function closePassword() {
        passwordFor = null;
        passwordError = "";
        joining = false;
    }
    function isAttempt(network: var): bool {
        return attempt !== null && attempt.name === network.name && Date.now() - attempt.time < 60000;
    }
    function fail(name: string, text: string) {
        const f = Object.assign({}, failures);
        f[name] = text;
        failures = f;
        clearFailures.restart();
    }
    function choose(network: var) {
        if (network.connected || network.stateChanging)
            return;
        const kind = Net.securityKind(network.security);
        if (network.known || kind === "open" || kind === "unknown") {
            closePassword();
            network.connect();
        } else if (kind === "enterprise") {
            configureEnterprise();
        } else if (passwordFor === network) {
            closePassword();
        } else {
            passwordFor = network;
            passwordError = "";
            joining = false;
        }
    }

    Component.onCompleted: Net.startScan(page)
    Component.onDestruction: Net.stopScan(page)
    Connections {
        target: Net
        function onWifiOnChanged() {
            if (!Net.wifiOn)
                page.closePassword();
        }
    }
    Timer {
        running: true
        interval: 4000
        onTriggered: page.justOpened = false
    }
    Timer {
        id: clearFailures
        interval: 5000
        onTriggered: page.failures = {}
    }

    // Ethernet.
    SectionLabel {
        text: "Ethernet"
        visible: Net.wiredDevices.length > 0
    }
    Repeater {
        model: Net.wiredDevices
        ListRow {
            required property var modelData
            icon: "ethernet-port"
            title: Net.wiredDevices.length > 1 ? modelData.name : "Ethernet"
            subtitle: !modelData.hasLink ? "Cable unplugged"
                : modelData.connected ? "Connected" + (modelData.linkSpeed > 0
                    ? " · " + (modelData.linkSpeed >= 1000 ? modelData.linkSpeed / 1000 + " Gb/s" : modelData.linkSpeed + " Mb/s") : "")
                : "Not connected"
            selected: modelData.connected
            interactive: false
        }
    }

    EmptyState {
        visible: !Net.wifi && Net.wiredDevices.length === 0
        icon: "globe"
        text: "No network devices"
    }
    EmptyState {
        visible: Net.wifi !== null && !Net.wifiOn
        icon: "wifi-off"
        text: Net.hardwareEnabled ? "Wi-Fi is off" : "Wi-Fi is turned off by a hardware switch"
    }

    SectionLabel {
        text: "Known networks"
        visible: page.known.length > 0
    }
    Repeater {
        model: page.known
        delegate: networkRow
    }

    SectionLabel {
        text: "Other networks"
        visible: Net.wifi !== null && Net.wifiOn
        busy: page.justOpened || page.others.length === 0
    }
    Repeater {
        model: page.others
        delegate: networkRow
    }
    EmptyState {
        visible: Net.wifi !== null && Net.wifiOn && page.networks.length === 0 && !page.justOpened
        icon: "wifi-zero"
        text: "No networks found"
    }

    Component {
        id: networkRow

        ListRow {
            id: row
            required property var modelData
            readonly property var network: modelData
            readonly property string kind: Net.securityKind(network.security)
            readonly property bool asking: page.passwordFor === network

            icon: Net.signalIcon(network.signalStrength)
            title: network.name
            selected: network.connected
            busy: network.stateChanging && !asking
            subtitle: page.failures[network.name] ?? (network.stateChanging ? "Connecting…"
                : kind === "enterprise" && !network.known ? "Requires setup in Network Settings" : "")
            error: page.failures[network.name] !== undefined
            // Hidden while connecting; it returns only if the attempt fails.
            expanded: asking && !network.stateChanging
            onClicked: page.choose(network)
            onRightClicked: if (network.known) network.forget()

            Icon {
                name: "lock"
                size: 11
                color: Theme.colors.textDim
                visible: row.kind === "psk" || row.kind === "enterprise"
                anchors.verticalCenter: parent.verticalCenter
            }

            expansion: PasswordField {
                id: field
                busy: page.joining
                error: page.passwordError
                onAccepted: text => {
                    page.joining = true;
                    page.attempt = { name: row.network.name, isNew: !row.network.known, time: Date.now(), forgotten: false };
                    page.passwordError = "";
                    // Collapse while connecting; a failure reopens it.
                    page.passwordFor = null;
                    row.network.connectWithPsk(text);
                }
                onCancelled: page.closePassword()
                Component.onCompleted: Qt.callLater(focusField)
                onVisibleChanged: if (visible) Qt.callLater(focusField)
            }

            Connections {
                target: row.network
                function onConnectedChanged() {
                    if (!row.network.connected)
                        return;
                    if (row.asking || page.isAttempt(row.network)) {
                        page.closePassword();
                        page.attempt = null;
                    }
                }
                function onConnectionFailed(reason) {
                    const typed = page.isAttempt(row.network);
                    page.joining = false;
                    if (typed && page.attempt.isNew && !page.attempt.forgotten) {
                        page.attempt = Object.assign({}, page.attempt, { forgotten: true });
                        row.network.forget();
                    }
                    if (typed || reason === ConnectionFailReason.NoSecrets) {
                        page.passwordFor = row.network;
                        page.passwordError = !typed ? "Enter the new password"
                            : reason === ConnectionFailReason.NoSecrets ? "Incorrect password" : "Couldn't connect";
                    } else {
                        page.fail(row.network.name, "Couldn't connect");
                    }
                }
            }
        }
    }
}
