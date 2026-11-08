pragma Singleton
// Session actions and the screen lock.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool locked: false
    // Keeps the screen awake while on (the control centre's Caffeine).
    property bool caffeine: false
    property string uptime: ""

    function lock() {
        ShellState.close();
        locked = true;
    }
    function logout() {
        Niri.quit();
    }
    function suspend() {
        lock();
        run(["systemctl", "suspend"]);
    }
    function reboot() {
        run(["systemctl", "reboot"]);
    }
    function poweroff() {
        run(["systemctl", "poweroff"]);
    }
    function run(command: var) {
        Quickshell.execDetached(command);
    }

    // "up 3 hours, 12 minutes" from /proc/uptime.
    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: {
            const seconds = parseFloat(text().split(" ")[0]);
            const hours = Math.floor(seconds / 3600);
            const minutes = Math.floor(seconds % 3600 / 60);
            root.uptime = "up " + (hours > 0 ? hours + "h " : "") + minutes + "m";
        }
    }
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: uptimeFile.reload()
    }
}
