pragma Singleton
// Which popup is open. Only one opens at a time; opening another closes it.
import QtQuick
import Quickshell

Singleton {
    // "", "control", "network", "bluetooth", "sound", "launcher",
    // "clipboard" or "dash".
    property string openPanel: ""

    property bool settingsOpen: false
    property string settingsPage: "appearance"
    function openSettings(page: string) {
        close();
        settingsPage = page || "appearance";
        settingsOpen = true;
        Prefs.refresh();
    }

    function toggle(name: string) {
        if (openPanel === name) {
            close();
            return;
        }
        openPanel = name;
    }
    function close() {
        openPanel = "";
    }
}
