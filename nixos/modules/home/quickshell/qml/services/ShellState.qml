pragma Singleton
// Which popup is open. Only one opens at a time; opening another closes it.
import QtQuick
import Quickshell

Singleton {
    // "", "control", "launcher", "clipboard" or "dash".
    property string openPanel: ""

    property bool settingsOpen: false
    property string settingsPage: "appearance"
    function openSettings(page: string) {
        close();
        settingsPage = page || "appearance";
        settingsOpen = true;
        Prefs.refresh();
    }

    // The control-centre page a bar status icon asked for ("" for the grid).
    property string controlPage: ""
    // A page opened directly from a widget has no parent grid to go back to.
    property bool controlStandalone: false
    function openControl(page: string) {
        if (openPanel === "control" && controlPage === page) {
            close();
            return;
        }
        controlStandalone = page !== "";
        controlPage = page;
        openPanel = "control";
    }

    function toggle(name: string) {
        if (openPanel === name) {
            close();
            return;
        }
        openPanel = "";
        controlPage = "";
        controlStandalone = false;
        openPanel = name;
    }
    function close() {
        openPanel = "";
        controlPage = "";
        controlStandalone = false;
    }
}
