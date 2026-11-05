pragma Singleton
// Which popup is open. Only one opens at a time; opening another closes it.
import QtQuick
import Quickshell

Singleton {
    // "", "control", "launcher" or "dash".
    property string openPanel: ""

    function toggle(name: string) {
        openPanel = openPanel === name ? "" : name;
    }
    function close() {
        openPanel = "";
    }
}
