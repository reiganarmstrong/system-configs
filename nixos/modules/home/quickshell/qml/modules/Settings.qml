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
import qs.modules.settings as Pages
import "settings/Catalog.js" as Catalog

FloatingWindow {
    id: window
    title: "Settings"
    implicitWidth: 960
    implicitHeight: 680
    minimumSize: Qt.size(820, 540)
    color: "transparent"
    visible: ShellState.settingsOpen && !Session.locked
    onClosed: ShellState.settingsOpen = false

    readonly property var pages: Catalog.pages
    readonly property var page: pages.find(p => p.key === ShellState.settingsPage) ?? pages[0]
    readonly property var filteredPages: pages.filter(p => (p.title + " " + p.words).toLowerCase().includes(search.text.trim().toLowerCase()))
    readonly property bool pageReady: content.status === Loader.Ready
    function pref(key, fallback) { return Prefs.get(key, fallback); }
    function set(key, value) { Prefs.set(key, value); }
    function launch(command) { Session.run(command); }
    property string confirmAction: ""
    onPageChanged: { confirmAction = ""; SettingsAdmin.error = ""; SettingsAdmin.notice = ""; }
    onVisibleChanged: if (!visible) confirmAction = ""
    Dialogs.FileDialog {
        id: wallpaperPicker
        title: "Choose wallpaper"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp)"]
        onAccepted: window.set("wallpaper", decodeURIComponent(selectedFile.toString().replace(/^file:\/\//, "")))
    }


    // Hyprland rounds the window's corners and draws its border, so the content
    // is a plain square fill; a second rounded border inside it doubled up.
    Rectangle {
        anchors.fill: parent
        color: "#ef1c1c20"

        Rectangle {
            id: sidebar
            // Widens with enlarged text so page names stay readable.
            width: Math.round(244 + 100 * Math.max(0, Prefs.get("textScale", 1) - 1))
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
                    background: Rectangle { radius: 8; color: "#12ffffff"; border.width: search.activeFocus ? 2 : 0; border.color: Theme.focusRing }
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
                    section.property: "group"
                    section.delegate: Item {
                        required property string section
                        width: navigation.width
                        height: Math.max(26, sectionText.implicitHeight + 10)
                        Label { id: sectionText; x: 10; anchors.bottom: parent.bottom; anchors.bottomMargin: 4; text: parent.section; dim: true; size: Theme.textSmall * 0.9 }
                    }
                    Controls.ScrollBar.vertical: Controls.ScrollBar { }
                    keyNavigationEnabled: true
                    activeFocusOnTab: true
                    onCurrentIndexChanged: if (activeFocus && currentIndex >= 0) ShellState.settingsPage = window.filteredPages[currentIndex].key
                    delegate: Rectangle {
                        id: navRow
                        required property var modelData
                        required property int index
                        width: navigation.width
                        height: Math.max(36, navText.implicitHeight + 16)
                        radius: 8
                        readonly property bool selected: window.page.key === modelData.key
                        color: selected ? Theme.selectFill : navMouse.containsMouse ? Theme.hoverFill : "transparent"
                        Icon { anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; name: navRow.modelData.icon; size: 16 }
                        Label { id: navText; anchors.left: parent.left; anchors.leftMargin: 36; anchors.verticalCenter: parent.verticalCenter; text: navRow.modelData.title; size: Theme.textSmall; width: parent.width - 40 }
                        MouseArea { id: navMouse; anchors.fill: parent; hoverEnabled: true; onClicked: ShellState.settingsPage = navRow.modelData.key }
                        Accessible.role: Accessible.PageTab
                        Accessible.name: modelData.title
                        Accessible.onPressAction: ShellState.settingsPage = modelData.key
                    }
                    Label { anchors.top: parent.top; width: parent.width; text: "No settings found"; dim: true; visible: navigation.count === 0 }
                }
                Label { text: Theme.user.fullName; weight: Font.DemiBold; Layout.fillWidth: true; Layout.leftMargin: 8; size: Theme.textSmall }
                Label { text: SettingsAdmin.activity || (Prefs.saving ? "Saving…" : "Changes save automatically"); dim: true; size: Theme.textSmall * 0.9; Layout.fillWidth: true; Layout.leftMargin: 8 }
            }
        }

        ColumnLayout {
            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 28
            anchors.rightMargin: 12
            spacing: 14
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                MouseArea { anchors.fill: parent; onPressed: window.startSystemMove() }
                Label { text: window.page.title; size: 19; weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
            }
            Label {
                Layout.fillWidth: true
                visible: Prefs.error !== "" || SettingsAdmin.error !== ""
                text: Prefs.error || SettingsAdmin.error
                textFormat: Text.PlainText
                color: Theme.colors.urgent
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                size: Theme.textSmall
            }
            Label {
                Layout.fillWidth: true
                visible: SettingsAdmin.notice !== "" && !Prefs.error && !SettingsAdmin.error
                text: SettingsAdmin.notice
                textFormat: Text.PlainText
                dim: true
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                size: Theme.textSmall
            }
            Rectangle {
                visible: Prefs.previewSeconds > 0
                Layout.fillWidth: true
                implicitHeight: previewRow.implicitHeight + 24
                color: Theme.withAlpha("#ffffff", 0.08)
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
                // Keep the scrollbar near the window edge in its own gutter.
                rightPadding: 24
                contentWidth: availableWidth
                Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
                Loader {
                    id: content
                    width: scroll.availableWidth
                    enabled: Prefs.ready
                    active: window.visible
                    sourceComponent: ({appearance: appearancePage, display: displayPage, sound: soundPage,
                        power: powerPage, notifications: notificationsPage, network: networkPage, bluetooth: bluetoothPage,
                        accounts: accountsPage, system: systemPage, accessibility: accessibilityPage, privacy: privacyPage,
                        apps: appsPage, defaults: defaultsPage, startup: startupPage, storage: storagePage,
                        time: timePage, printers: printersPage, updates: updatesPage})[window.page.key]
                }
            }
        }
    }
    // No close button: Esc (after clearing a search), Ctrl+W or Super+Q.
    // Ctrl+F or / searches.
    Shortcut { sequence: "Ctrl+F"; enabled: window.visible && !wallpaperPicker.visible; onActivated: search.forceActiveFocus() }
    // "/" too, unless a text field has focus, where it's just a slash.
    Shortcut {
        sequence: "/"
        enabled: window.visible && !wallpaperPicker.visible
            && window.contentItem.Window.activeFocusItem?.cursorPosition === undefined
        onActivated: {
            search.forceActiveFocus();
            search.selectAll();
        }
    }
    Shortcut { sequence: "Ctrl+W"; enabled: window.visible && !wallpaperPicker.visible; onActivated: ShellState.settingsOpen = false }
    Shortcut {
        sequence: "Escape"
        enabled: window.visible && !wallpaperPicker.visible
        onActivated: {
            if (content.item?.handleEscape && content.item.handleEscape()) return;
            if (search.text) search.text = ""; else ShellState.settingsOpen = false;
        }
    }

    Component { id: appearancePage; Pages.AppearancePage { host: window } }
    Component { id: displayPage; Pages.DisplayPage { host: window } }
    Component { id: soundPage; Pages.SoundPage { host: window } }
    Component { id: powerPage; Pages.PowerPage { host: window } }
    Component { id: notificationsPage; Pages.NotificationsPage { host: window } }
    Component { id: networkPage; Pages.NetworkPage { host: window } }
    Component { id: bluetoothPage; Pages.BluetoothPage { host: window } }
    Component { id: accountsPage; Pages.AccountsPage { host: window } }
    Component { id: systemPage; Pages.SystemPage { host: window } }
    Component { id: accessibilityPage; Pages.AccessibilityPage { host: window } }
    Component { id: privacyPage; Pages.PrivacyPage { host: window } }
    Component { id: appsPage; Pages.AppsPage { host: window } }
    Component { id: defaultsPage; Pages.DefaultsPage { host: window } }
    Component { id: startupPage; Pages.StartupPage { host: window } }
    Component { id: storagePage; Pages.StoragePage { host: window } }
    Component { id: timePage; Pages.TimePage { host: window } }
    Component { id: printersPage; Pages.PrintersPage { host: window } }
    Component { id: updatesPage; Pages.UpdatesPage { host: window } }
}
