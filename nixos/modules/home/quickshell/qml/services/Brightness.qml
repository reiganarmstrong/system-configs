pragma Singleton
// Display backlight through brightnessctl. Absent on machines without one.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool available: false
    property real level: 1

    function set(value: real) {
        const v = Math.max(0.01, Math.min(1, value));
        level = v;
        Quickshell.execDetached(["brightnessctl", "--quiet", "set", Math.round(v * 100) + "%"]);
    }
    function step(delta: real) {
        set(level + delta);
    }

    Process {
        running: true
        command: ["brightnessctl", "--machine-readable", "--class=backlight", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                // name,class,current,percent,max
                const fields = text.trim().split(",");
                if (fields.length >= 4) {
                    root.available = true;
                    root.level = parseInt(fields[3]) / 100;
                }
            }
        }
    }
}
