pragma Singleton
// Display backlight through brightnessctl. Absent on machines without one.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool available: false
    property real level: 1
    property real pending: -1

    function flush() {
        if (pending < 0 || writer.running) return;
        writer.command = ["brightnessctl", "--class=backlight", "--quiet", "set", Math.round(pending * 100) + "%"];
        pending = -1;
        writer.running = true;
    }
    Timer { id: throttle; interval: 40; onTriggered: root.flush() }
    Process {
        id: writer
        onExited: (code, status) => { if (root.pending >= 0) throttle.restart(); }
    }


    function set(value: real) {
        if (!available) return;
        const v = Math.max(0.01, Math.min(1, value));
        level = v;
        pending = v;
        if (!throttle.running) throttle.start();
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
