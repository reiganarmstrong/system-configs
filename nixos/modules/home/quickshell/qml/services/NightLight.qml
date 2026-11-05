pragma Singleton
// Warmer colours in the evening, through hyprsunset.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool enabled: false

    Process {
        running: root.enabled
        command: ["hyprsunset", "--temperature", "4200"]
    }
}
