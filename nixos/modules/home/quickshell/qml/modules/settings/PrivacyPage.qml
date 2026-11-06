import QtQuick
import qs.components.settings
import qs.services

Column {
    required property var host
    property bool clearConfirmed: false
    spacing: 10
    SettingToggle {
        title: "Capture clipboard history"
        detail: "Keep up to 200 recent text and image selections locally. App-marked sensitive selections are skipped."
        enabled: Clipboard.ready && !Clipboard.mutating
        checked: !Clipboard.paused
        onToggled: v => Clipboard.pause(!v)
    }
    SettingAction {
        title: "Clear clipboard history"
        detail: "Permanently remove saved clipboard entries from this account."
        buttonText: "Clear…"
        enabled: Clipboard.items.length > 0
        onActivated: clearConfirmed = true
    }
    SettingRow {
        visible: clearConfirmed
        title: "Clear saved clipboard entries?"
        Row {
            spacing: 8
            SettingButton {
                text: "Cancel"
                onClicked: clearConfirmed = false
            }
            SettingButton {
                text: "Clear"
                destructive: true
                onClicked: {
                    Clipboard.clear();
                    clearConfirmed = false;
                }
            }
        }
    }
    SettingToggle {
        title: "Mute microphone"
        detail: "Mute the default recording device system-wide."
        enabled: Audio.source !== null
        checked: Audio.micMuted
        onToggled: v => Audio.toggleMic()
    }
    SettingToggle {
        title: "Do Not Disturb"
        detail: "Send normal notifications to history. Critical alerts can still appear."
        checked: Notifs.doNotDisturb
        onToggled: v => Prefs.set("doNotDisturb", v)
    }
    SettingAction {
        title: "Automatic lock"
        detail: "Configure inactivity locking and display sleep."
        buttonText: "Configure"
        onActivated: ShellState.openSettings("power")
    }
    SettingAction {
        title: "Application permissions"
        detail: "Inspect Flatpak permissions and reset per-user permission overrides."
        buttonText: "Applications"
        onActivated: ShellState.openSettings("apps")
    }
    Component.onCompleted: Clipboard.refresh()
}
