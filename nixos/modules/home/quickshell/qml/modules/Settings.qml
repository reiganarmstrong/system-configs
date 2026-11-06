// A normal, movable Settings window. No screen-sized overlay or backdrop.
import QtQuick
import QtQuick.Dialogs as Dialogs
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import Quickshell
import Quickshell.Services.UPower
import qs.components
import qs.components.settings
import qs.services

FloatingWindow {
    id: window
    title: "Settings"
    implicitWidth: 960
    implicitHeight: 680
    minimumSize: Qt.size(820, 540)
    color: "transparent"
    visible: ShellState.settingsOpen && !Session.locked
    onClosed: ShellState.settingsOpen = false

    readonly property var pages: [
        {key: "appearance", title: "Appearance", icon: "palette", words: "transparency opacity glass animation motion clock seconds battery corners gaps wallpaper"},
        {key: "display", title: "Displays", icon: "monitor", words: "resolution refresh scale rotation brightness screen monitors"},
        {key: "sound", title: "Sound", icon: "volume-2", words: "audio microphone volume output input speakers headphones mute"},
        {key: "input", title: "Keyboard & pointer", icon: "keyboard", words: "touchpad mouse speed acceleration scroll tap typing caps layout repeat shortcuts"},
        {key: "power", title: "Power & lock", icon: "battery-charging", words: "caffeine sleep suspend idle screen saver performance balanced energy"},
        {key: "notifications", title: "Notifications", icon: "bell", words: "focus disturb banners duration history alerts"},
        {key: "network", title: "Network", icon: "wifi", words: "wifi wi-fi ethernet internet vpn ip connections airplane"},
        {key: "bluetooth", title: "Bluetooth", icon: "bluetooth", words: "pair headphones mouse wireless devices"},
        {key: "accounts", title: "Accounts & calendars", icon: "user-round", words: "apple icloud google outlook microsoft password keys login calendar"},
        {key: "system", title: "Apps & system", icon: "settings", words: "about storage disks files default browser operating version kernel memory apps reset"},
    ]
    readonly property var page: pages.find(p => p.key === ShellState.settingsPage) ?? pages[0]
    readonly property var filteredPages: pages.filter(p => (p.title + " " + p.words).toLowerCase().includes(search.text.trim().toLowerCase()))
    function pref(key, fallback) { return Prefs.get(key, fallback); }
    function set(key, value) { Prefs.set(key, value); }
    function launch(command) { Session.run(command); }
    property string confirmAction: ""
    readonly property var browsers: DesktopEntries.applications.values.filter(a => !a.noDisplay && a.categories.includes("WebBrowser")).sort((a,b) => a.name.localeCompare(b.name))
    Dialogs.FileDialog {
        id: wallpaperPicker
        title: "Choose wallpaper"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp)"]
        onAccepted: window.set("wallpaper", decodeURIComponent(selectedFile.toString().replace(/^file:\/\//, "")))
    }


    // Hyprland rounds the window's corners and draws its rim, so the content
    // is a plain square fill; a second rounded border inside it doubled up.
    Rectangle {
        anchors.fill: parent
        color: "#ef1c1c20"

        Rectangle {
            id: sidebar
            width: 224
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: "#f5151518"
            Rectangle { anchors.right: parent.right; height: parent.height; width: 1; color: "#10ffffff" }
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    MouseArea { anchors.fill: parent; onPressed: window.startSystemMove() }
                    Label { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 8; text: "Settings"; weight: Font.Bold }
                }
                Controls.TextField {
                    id: search
                    Layout.fillWidth: true
                    implicitHeight: 34
                    placeholderText: "Search settings"
                    placeholderTextColor: Theme.colors.textDim
                    color: "white"
                    font.family: Theme.font
                    font.pointSize: Theme.textSmall
                    leftPadding: 10
                    Accessible.name: "Search settings"
                    background: Rectangle { radius: 8; color: "#12ffffff"; border.width: search.activeFocus ? 2 : 0; border.color: "#5b9bff" }
                    onAccepted: if (window.filteredPages.length) ShellState.settingsPage = window.filteredPages[0].key
                }
                ListView {
                    id: navigation
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 3
                    model: window.filteredPages
                    currentIndex: window.filteredPages.findIndex(p => p.key === window.page.key)
                    keyNavigationEnabled: true
                    activeFocusOnTab: true
                    onCurrentIndexChanged: if (activeFocus && currentIndex >= 0) ShellState.settingsPage = window.filteredPages[currentIndex].key
                    delegate: Rectangle {
                        id: navRow
                        required property var modelData
                        required property int index
                        width: navigation.width
                        height: 36
                        radius: 8
                        readonly property bool selected: window.page.key === modelData.key
                        color: selected ? Theme.colors.highlight : navMouse.containsMouse ? "#12ffffff" : "transparent"
                        Icon { anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; name: navRow.modelData.icon; size: 16 }
                        Label { anchors.left: parent.left; anchors.leftMargin: 36; anchors.verticalCenter: parent.verticalCenter; text: navRow.modelData.title; size: Theme.textSmall; width: parent.width - 40 }
                        MouseArea { id: navMouse; anchors.fill: parent; hoverEnabled: true; onClicked: ShellState.settingsPage = navRow.modelData.key }
                        Accessible.role: Accessible.PageTab
                        Accessible.name: modelData.title
                        Accessible.onPressAction: ShellState.settingsPage = modelData.key
                    }
                    Label { anchors.top: parent.top; width: parent.width; text: "No settings found"; dim: true; visible: navigation.count === 0 }
                }
                Label { text: Theme.user.fullName; weight: Font.DemiBold; Layout.leftMargin: 8; size: Theme.textSmall }
                Label { text: Prefs.saving ? "Saving…" : "Changes save automatically"; dim: true; size: Theme.textSmall * 0.9; Layout.leftMargin: 8 }
            }
        }

        ColumnLayout {
            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 28
            spacing: 14
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                MouseArea { anchors.fill: parent; onPressed: window.startSystemMove() }
                Label { text: window.page.title; size: 19; weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
            }
            Label {
                Layout.fillWidth: true
                visible: Prefs.error !== ""
                text: Prefs.error
                color: Theme.colors.urgent
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                size: Theme.textSmall
            }
            Rectangle {
                visible: Prefs.previewSeconds > 0
                Layout.fillWidth: true
                implicitHeight: previewRow.implicitHeight + 24
                color: "#242f7cf6"
                radius: 10
                RowLayout {
                    id: previewRow
                    anchors.fill: parent
                    anchors.margins: 12
                    Label { text: "Keep display changes? Reverting in " + Prefs.previewSeconds + "s"; Layout.fillWidth: true; wrapMode: Text.Wrap; elide: Text.ElideNone; size: Theme.textSmall }
                    SettingButton { text: "Revert"; onClicked: Prefs.displayRevert() }
                    SettingButton { text: "Keep"; primary: true; onClicked: Prefs.displayKeep() }
                }
            }
            Controls.ScrollView {
                id: scroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth
                Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
                Loader {
                    id: content
                    width: scroll.availableWidth
                    enabled: Prefs.ready
                    sourceComponent: ({appearance: appearancePage, display: displayPage, sound: soundPage, input: inputPage,
                        power: powerPage, notifications: notificationsPage, network: networkPage, bluetooth: bluetoothPage,
                        accounts: accountsPage, system: systemPage})[window.page.key]
                }
            }
        }
    }
    // No close button: Esc (after clearing a search), Ctrl+W or Super+Q.
    Shortcut { sequence: "Ctrl+F"; enabled: window.visible && !wallpaperPicker.visible; onActivated: search.forceActiveFocus() }
    Shortcut { sequence: "Ctrl+W"; enabled: window.visible && !wallpaperPicker.visible; onActivated: ShellState.settingsOpen = false }
    Shortcut {
        sequence: "Escape"
        enabled: window.visible && !wallpaperPicker.visible
        onActivated: { if (search.text) search.text = ""; else ShellState.settingsOpen = false; }
    }

    Component {
        id: appearancePage
        Column {
            spacing: 10
            SettingLevel { title: "Panel opacity"; detail: "More opaque panels show less of the wallpaper."; value: window.pref("panelOpacity", 0.55); minimum: 0.35; maximum: 1; onMoved: v => window.set("panelOpacity", Math.round(v * 100) / 100) }
            SettingToggle { title: "Reduce motion"; detail: "Disable window animations and popup transitions."; checked: window.pref("reduceMotion", false); onToggled: v => window.set("reduceMotion", v) }
            SettingToggle { title: "24-hour clock"; checked: window.pref("clock24h", false); onToggled: v => window.set("clock24h", v) }
            SettingToggle { title: "Show seconds"; checked: window.pref("showSeconds", false); onToggled: v => window.set("showSeconds", v) }
            SettingToggle { title: "Battery percentage"; checked: window.pref("showBatteryPercent", true); onToggled: v => window.set("showBatteryPercent", v) }
            SettingLevel { title: "Window spacing"; value: window.pref("gaps", 5); minimum: 0; maximum: 25; multiplier: 1; suffix: " px"; onMoved: v => window.set("gaps", Math.round(v)) }
            SettingLevel { title: "Corner radius"; value: window.pref("rounding", 14); minimum: 0; maximum: 30; multiplier: 1; suffix: " px"; onMoved: v => window.set("rounding", Math.round(v)) }
            SettingAction { title: "Wallpaper"; detail: window.pref("wallpaper", "") ? window.pref("wallpaper", "").split("/").pop() : "Default desktop wallpaper"; buttonText: "Choose…"; onActivated: wallpaperPicker.open() }
            SettingAction { title: "Restore default wallpaper"; buttonText: "Restore"; enabled: window.pref("wallpaper", "") !== ""; onActivated: window.set("wallpaper", "") }
            SettingRow { title: "Theme"; detail: "Dark · " + Theme.font + " · " + Theme.data.icons.replace(/-/g, " ") + " icons\nFonts and the dark system theme are shared by your VM and laptop configuration." }
        }
    }
    Component {
        id: displayPage
        Column {
            spacing: 10
            SettingLevel {
                title: "Brightness"
                detail: Brightness.available ? "Built-in display backlight" : "This display has no adjustable backlight."
                enabled: Brightness.available
                value: Brightness.level
                minimum: 0.01
                onMoved: v => Brightness.set(v)
            }
            Repeater {
                model: Prefs.monitors
                Column {
                    id: displayCard
                    required property var modelData
                    width: parent.width
                    spacing: 10
                    property string mode: modelData.width + "x" + modelData.height + "@" + modelData.refreshRate.toFixed(5)
                    property real scale: modelData.scale
                    property int rotation: modelData.transform
                    readonly property var modes: [...new Set([modelData.width + "x" + modelData.height + "@" + modelData.refreshRate.toFixed(5), ...modelData.availableModes.map(m => m.replace("Hz", ""))])]
                    SettingRow { title: displayCard.modelData.name; detail: displayCard.modelData.description + "\n" + displayCard.modelData.width + " × " + displayCard.modelData.height + " at " + displayCard.modelData.refreshRate.toFixed(2) + " Hz" }
                    SettingChoice { title: "Resolution & refresh"; enabled: !Prefs.system.fixedDisplayMode; detail: Prefs.system.fixedDisplayMode ? "VNC resolution is fixed. Use Scale to change the desktop size." : ""; choiceWidth: 230; options: displayCard.modes; value: displayCard.mode; onChosen: v => displayCard.mode = v }
                    SettingChoice { title: "Scale"; options: ["75%", "100%", "125%", "150%", "175%", "200%", "250%", "300%"]; values: [0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3]; value: displayCard.scale; onChosen: v => displayCard.scale = v }
                    SettingChoice { title: "Rotation"; options: ["Normal", "90°", "180°", "270°"]; values: [0, 1, 2, 3]; value: displayCard.rotation; onChosen: v => displayCard.rotation = v }
                    SettingAction {
                        title: "Apply display changes"
                        detail: "Keep the new settings within 15 seconds, or they will revert."
                        buttonText: "Preview"
                        enabled: Prefs.previewSeconds === 0
                        onActivated: Prefs.displayPreview({output: displayCard.modelData.name, mode: displayCard.mode, scale: displayCard.scale, transform: displayCard.rotation})
                    }
                }
            }
            SettingAction { title: "Arrange displays"; enabled: !Prefs.system.fixedDisplayMode; detail: Prefs.system.fixedDisplayMode ? "This VM has one fixed virtual monitor." : "Position multiple monitors. Arrangement changes last for this session."; onActivated: window.launch(["wdisplays"]) }
            SettingAction { title: "Refresh displays"; detail: "Detect newly connected monitors."; buttonText: "Refresh"; onActivated: Prefs.refresh() }
        }
    }
    Component {
        id: soundPage
        Column {
            spacing: 10
            SettingChoice {
                title: "Output device"
                choiceWidth: 280
                options: Audio.outputs.map(n => n.description || n.name)
                values: Audio.outputs.map(n => n.id)
                value: Audio.sink?.id
                enabled: Audio.outputs.length > 0
                onChosen: v => Audio.selectOutput(Audio.outputs.find(n => n.id === v))
            }
            SettingLevel { title: "Output volume"; value: Audio.volume; enabled: Audio.sink !== null; onMoved: v => Audio.setVolume(v) }
            SettingToggle { title: "Mute output"; checked: Audio.muted; enabled: Audio.sink !== null; onToggled: v => Audio.toggleMute() }
            SettingChoice {
                title: "Input device"
                choiceWidth: 280
                options: Audio.inputs.map(n => n.description || n.name)
                values: Audio.inputs.map(n => n.id)
                value: Audio.source?.id
                enabled: Audio.inputs.length > 0
                onChosen: v => Audio.selectInput(Audio.inputs.find(n => n.id === v))
            }
            SettingLevel { title: "Microphone level"; value: Audio.micVolume; enabled: Audio.source !== null; onMoved: v => Audio.setMicVolume(v) }
            SettingToggle { title: "Mute microphone"; checked: Audio.micMuted; enabled: Audio.source !== null; onToggled: v => Audio.toggleMic() }
            SettingAction { title: "Application volume & device profiles"; detail: "Adjust individual apps, channel balance and hardware profiles."; onActivated: window.launch(["pavucontrol"]) }
        }
    }
    Component {
        id: inputPage
        Column {
            spacing: 10
            SettingChoice { title: "Keyboard layout"; options: ["English (US)", "English (UK)", "German", "French", "Spanish", "US + UK"]; values: ["us", "gb", "de", "fr", "es", "us,gb"]; value: window.pref("keyboardLayout", "us"); onChosen: v => window.set("keyboardLayout", v) }
            SettingChoice { title: "Caps Lock behavior"; options: ["Caps Lock", "Escape", "Control", "Swap Caps Lock and Escape"]; values: ["", "caps:escape", "ctrl:nocaps", "caps:swapescape"]; value: window.pref("capsLock", ""); onChosen: v => window.set("capsLock", v) }
            SettingLevel { title: "Key repeat rate"; value: window.pref("repeatRate", 25); minimum: 5; maximum: 60; multiplier: 1; suffix: "/s"; onMoved: v => window.set("repeatRate", Math.round(v)) }
            SettingLevel { title: "Key repeat delay"; value: window.pref("repeatDelay", 600); minimum: 150; maximum: 1000; multiplier: 1; suffix: " ms"; onMoved: v => window.set("repeatDelay", Math.round(v / 10) * 10) }
            SettingLevel { title: "Pointer speed"; value: window.pref("pointerSpeed", 0); minimum: -1; maximum: 1; multiplier: 1; decimals: 2; suffix: ""; onMoved: v => window.set("pointerSpeed", Math.round(v * 100) / 100) }
            SettingChoice { title: "Pointer acceleration"; options: ["Adaptive", "Off (flat)"]; values: ["adaptive", "flat"]; value: window.pref("pointerAcceleration", "adaptive"); onChosen: v => window.set("pointerAcceleration", v) }
            SettingToggle { title: "Mouse natural scrolling"; checked: window.pref("naturalScroll", false); onToggled: v => window.set("naturalScroll", v) }
            SettingLevel { title: "Scroll speed"; value: window.pref("scrollFactor", 1); minimum: 0.2; maximum: 3; multiplier: 1; decimals: 1; suffix: "×"; onMoved: v => window.set("scrollFactor", Math.round(v * 10) / 10) }
            SettingToggle { title: "Touchpad natural scrolling"; checked: window.pref("touchpadNaturalScroll", true); onToggled: v => window.set("touchpadNaturalScroll", v) }
            SettingToggle { title: "Tap to click"; checked: window.pref("tapToClick", true); onToggled: v => window.set("tapToClick", v) }
            SettingToggle { title: "Disable touchpad while typing"; checked: window.pref("disableWhileTyping", true); onToggled: v => window.set("disableWhileTyping", v) }
            SettingToggle { title: "Two-finger right-click"; checked: window.pref("twoFingerClick", true); onToggled: v => window.set("twoFingerClick", v) }
            SettingToggle { title: "Focus follows pointer"; detail: "Off keeps focus on the window you clicked."; checked: window.pref("focusFollowsMouse", false); onToggled: v => window.set("focusFollowsMouse", v) }
            SettingRow { title: "Window shortcuts"; detail: "Super+Space  Search apps\nSuper+,  Settings\nSuper+S  Control center\nSuper+T  Terminal\nSuper+Q  Close window\nSuper+F  Full screen\nSuper+V  Float window\nSuper+arrows  Focus window\nSuper+Shift+arrows  Move window\nSuper+1…0  Switch workspace\nSuper+Shift+1…0  Move to workspace\nSuper+drag  Move window\nSuper+right-drag  Resize window\nSuper+L  Lock\n\nSuper is the Windows key on most keyboards and Command through VNC." }
        }
    }
    Component {
        id: powerPage
        Column {
            spacing: 10
            SettingRow { title: "Battery"; detail: Battery.present ? Math.round(Battery.level * 100) + "% · " + (Battery.charging ? "Charging" : "On battery") : "No battery detected on this machine." }
            SettingChoice {
                title: "Power mode"
                options: PowerProfiles.hasPerformanceProfile ? ["Power saver", "Balanced", "Performance"] : ["Power saver", "Balanced"]
                values: PowerProfiles.hasPerformanceProfile ? [0, 1, 2] : [0, 1]
                value: PowerProfiles.profile
                onChosen: v => PowerProfiles.profile = v
            }
            SettingToggle { title: "Keep awake"; detail: "Caffeine pauses automatic locking, screen off and suspend."; checked: Session.caffeine; onToggled: v => Session.caffeine = v }
            SettingChoice { title: "Lock after inactivity"; options: ["1 minute", "2 minutes", "5 minutes", "10 minutes", "15 minutes", "30 minutes", "60 minutes"]; values: [1, 2, 5, 10, 15, 30, 60]; value: window.pref("lockMinutes", 5); onChosen: v => { window.set("lockMinutes", v); if (v > window.pref("screenOffMinutes", 6)) window.set("screenOffMinutes", v); if (window.pref("suspendMinutes", 0) > 0 && v > window.pref("suspendMinutes", 0)) window.set("suspendMinutes", v); } }
            SettingChoice { title: "Turn screen off after"; options: ["1 minute", "5 minutes", "6 minutes", "10 minutes", "15 minutes", "30 minutes", "60 minutes", "120 minutes"]; values: [1, 5, 6, 10, 15, 30, 60, 120]; value: window.pref("screenOffMinutes", 6); onChosen: v => { window.set("screenOffMinutes", v); if (v < window.pref("lockMinutes", 5)) window.set("lockMinutes", v); if (window.pref("suspendMinutes", 0) > 0 && v > window.pref("suspendMinutes", 0)) window.set("suspendMinutes", v); } }
            SettingChoice { title: "Suspend after"; detail: "Keep this off for reliable remote access to the VM."; options: ["Never", "5 minutes", "15 minutes", "30 minutes", "60 minutes", "120 minutes"]; values: [0, 5, 15, 30, 60, 120]; value: window.pref("suspendMinutes", 0); onChosen: v => { window.set("suspendMinutes", v); if (v > 0 && v < window.pref("screenOffMinutes", 6)) { window.set("screenOffMinutes", v); if (v < window.pref("lockMinutes", 5)) window.set("lockMinutes", v); } } }
            SettingAction { title: "Lock screen"; buttonText: "Lock"; onActivated: Session.lock() }
            SettingRow {
                title: "Session"
                Row {
                    spacing: 8
                    SettingButton { text: "Log out"; onClicked: window.confirmAction = "logout" }
                    SettingButton { text: "Restart"; onClicked: window.confirmAction = "reboot" }
                    SettingButton { text: "Shut down"; destructive: true; onClicked: window.confirmAction = "poweroff" }
                }
            }
            SettingRow {
                visible: window.confirmAction !== ""
                title: "Confirm " + ({logout: "log out", reboot: "restart", poweroff: "shut down"})[window.confirmAction] + "?"
                Row {
                    spacing: 8
                    SettingButton { text: "Cancel"; onClicked: window.confirmAction = "" }
                    SettingButton { text: "Confirm"; destructive: true; onClicked: { const action = window.confirmAction; window.confirmAction = ""; Session[action](); } }
                }
            }
        }
    }
    Component {
        id: notificationsPage
        Column {
            spacing: 10
            SettingToggle { title: "Do Not Disturb"; detail: "Send notifications to history. Critical alerts still appear."; checked: Notifs.doNotDisturb; onToggled: v => window.set("doNotDisturb", v) }
            SettingChoice { title: "Banner duration"; options: ["3 seconds", "6 seconds", "8 seconds", "12 seconds", "Until dismissed"]; values: [3, 6, 8, 12, 0]; value: window.pref("bannerSeconds", 6); onChosen: v => window.set("bannerSeconds", v) }
            SettingAction { title: "Notification history"; detail: Notifs.history.length + " notifications"; buttonText: "Open"; onActivated: { ShellState.settingsOpen = false; ShellState.toggle("dash"); } }
            SettingAction { title: "Clear history"; enabled: Notifs.history.length > 0; buttonText: "Clear"; onActivated: Notifs.clearAll() }
        }
    }
    Component {
        id: networkPage
        Column {
            spacing: 10
            SettingRow { title: Net.title; detail: Net.status + (Prefs.system.ip ? "\n" + Prefs.system.ip.trim() : "") }
            SettingToggle { title: "Wi-Fi"; detail: Net.wifi ? "Enable the wireless adapter." : "No Wi-Fi adapter detected."; enabled: Net.wifi !== null; checked: Net.wifiOn; onToggled: v => Net.setWifi(v) }
            SettingToggle { title: "Airplane mode"; detail: "Turn off Wi-Fi and Bluetooth radios."; enabled: Net.wifi !== null || Bt.available; checked: !Net.wifiOn && !Bt.enabled; onToggled: v => { Net.setWifi(!v); Bt.setEnabled(!v); } }
            SettingAction { title: "Connections & VPN"; detail: "Configure Wi-Fi passwords, Ethernet, DNS, proxies and VPN connections."; onActivated: window.launch(["nm-connection-editor"]) }
            SettingAction { title: "Join a Wi-Fi network"; detail: "Choose a network and enter its password securely."; enabled: Net.wifi !== null; onActivated: window.launch(["nm-connection-editor", "--create", "--type", "802-11-wireless"]) }
        }
    }
    Component {
        id: bluetoothPage
        Column {
            spacing: 10
            SettingToggle { title: "Bluetooth"; detail: Bt.available ? Bt.status : "No Bluetooth adapter detected. Pairing will be available on supported hardware."; enabled: Bt.available; checked: Bt.enabled; onToggled: v => Bt.setEnabled(v) }
            Repeater {
                model: Bt.connected
                SettingRow { required property var modelData; title: modelData.name; detail: "Connected" }
            }
            SettingAction { title: "Devices & pairing"; detail: "Find devices, pair securely, connect or remove saved devices."; enabled: Bt.available; onActivated: window.launch(["blueman-manager"]) }
        }
    }
    Component {
        id: accountsPage
        Column {
            spacing: 10
            SettingRow { title: Theme.user.fullName; detail: "User account: " + Theme.user.name }
            SettingAction { title: "Online accounts"; detail: "Connect Google, Microsoft 365 / Outlook, and iCloud through WebDAV / CalDAV."; onActivated: CalendarData.openAccounts() }
            SettingAction { title: "Calendars"; detail: "Manage calendars, view events and create appointments."; onActivated: CalendarData.openCalendar() }
            SettingRow { title: "Apple iCloud"; detail: "In Online Accounts choose WebDAV. Use https://caldav.icloud.com/ with your Apple Account email and an app-specific password from account.apple.com." }
            SettingAction { title: "Passwords & keys"; detail: "Manage saved passwords, login keyrings and encryption keys."; onActivated: window.launch(["seahorse"]) }
            SettingAction {
                title: "Account password"
                detail: Theme.data.mutablePassword ? "Change your login password in a terminal. Update your login keyring separately in Passwords & keys." : "This test VM uses a fixed account password."
                buttonText: "Change…"
                enabled: Theme.data.mutablePassword ?? false
                onActivated: window.launch(["ghostty", "-e", "passwd"])
            }
        }
    }
    Component {
        id: systemPage
        Column {
            spacing: 10
            SettingRow { title: Prefs.system.hostname ?? "System"; detail: (Prefs.system.os ?? "") + "\nKernel " + (Prefs.system.kernel ?? "") + "\n" + (Prefs.system.memoryGiB ?? "") + " GiB memory" }
            SettingRow { title: "Storage"; detail: (Prefs.system.storageFreeGiB ?? "") + " GiB available of " + (Prefs.system.storageTotalGiB ?? "") + " GiB" }
            SettingAction { title: "Disks & files"; detail: "Inspect storage, partitions and mounted volumes."; buttonText: "Disks…"; onActivated: window.launch(["gnome-disks"]) }
            SettingAction { title: "Files"; detail: "Browse files and choose default applications with Open With."; onActivated: window.launch(["nautilus"]) }
            SettingChoice {
                title: "Default browser"
                choiceWidth: 260
                options: window.browsers.map(a => a.name)
                values: window.browsers.map(a => a.id + ".desktop")
                value: Prefs.system.browser
                onChosen: v => Prefs.setBrowser(v)
            }
            SettingAction { title: "Application volumes"; detail: "Control the volume and audio device for each running application."; onActivated: window.launch(["pavucontrol"]) }
            SettingAction { title: "Reset desktop preferences"; detail: "Restore default appearance, input, notifications and lock timing. Confirmed display modes and online accounts stay as they are."; buttonText: "Reset…"; onActivated: resetConfirm.visible = true }
            SettingRow {
                id: resetConfirm
                visible: false
                title: "Restore default preferences?"
                Row {
                    spacing: 8
                    SettingButton { text: "Cancel"; onClicked: resetConfirm.visible = false }
                    SettingButton { text: "Reset"; destructive: true; onClicked: { Prefs.reset(); resetConfirm.visible = false; } }
                }
            }
        }
    }
}
