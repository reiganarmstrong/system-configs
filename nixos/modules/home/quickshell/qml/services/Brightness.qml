pragma Singleton
// Brightness per output: the built-in panel through brightnessctl, external
// monitors over DDC/CI through ddcutil. The keys and the Control Center slider
// act on the focused output, falling back to the built-in panel when the
// focused monitor can't be adjusted.
import QtQuick
import Quickshell
import Quickshell.Io
import "ddc.js" as Ddc

Singleton {
    id: root

    // "builtin" or a Hyprland output name -> {kind: "backlight" | "ddc", bus, max, level}.
    property var targets: ({})
    readonly property string target: Ddc.pickTarget(targets, Compositor.focusedOutput)
    readonly property bool available: target !== ""
    readonly property real level: targets[target]?.level ?? 1
    // Writes waiting for the writer, by target; only the latest value is kept.
    property var pending: ({})

    function set(value: real) {
        if (!available)
            return;
        const name = target;
        const v = Math.max(0.01, Math.min(1, value));
        targets = Object.assign({}, targets, {[name]: Object.assign({}, targets[name], {level: v})});
        pending[name] = v;
        if (!throttle.running)
            throttle.start();
    }
    function step(delta: real) {
        set(level + delta);
    }

    function flush() {
        if (writer.running)
            return;
        const name = Object.keys(pending)[0];
        if (name === undefined)
            return;
        const v = pending[name];
        delete pending[name];
        const t = targets[name];
        if (!t) {
            flush();
            return;
        }
        writer.command = t.kind === "ddc"
            ? ["ddcutil", "--bus", String(t.bus), "--noverify", "setvcp", "10", String(Math.max(1, Math.round(v * t.max)))]
            : ["brightnessctl", "--class=backlight", "--quiet", "set", Math.round(v * 100) + "%"];
        writer.running = true;
    }
    // DDC/CI writes take a few hundred milliseconds; held keys coalesce into
    // the latest value instead of queueing every step.
    Timer { id: throttle; interval: 40; onTriggered: root.flush() }
    Process {
        id: writer
        onExited: (code, status) => {
            if (Object.keys(root.pending).length > 0)
                throttle.restart();
        }
    }

    // The built-in panel.
    Process {
        running: true
        command: ["brightnessctl", "--machine-readable", "--class=backlight", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                // name,class,current,percent,max
                const fields = text.trim().split(",");
                if (fields.length >= 4)
                    root.targets = Object.assign({}, root.targets, {
                        builtin: {kind: "backlight", bus: -1, max: 100, level: parseInt(fields[3]) / 100}
                    });
            }
        }
    }

    // External monitors: find them, then read each one's brightness. Runs at
    // start and again shortly after a monitor is plugged in or removed.
    property var detected: []
    Process {
        id: detector
        running: true
        command: ["ddcutil", "detect"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.detected = Ddc.parseDetect(text);
                if (root.detected.length === 0) {
                    root.replaceMonitors({});
                    return;
                }
                reader.command = ["sh", "-c",
                    "for b; do printf '%s ' \"$b\"; ddcutil --bus \"$b\" getvcp 10 --brief 2>/dev/null || echo; done",
                    "sh"].concat(root.detected.map(d => String(d.bus)));
                reader.running = true;
            }
        }
    }
    Process {
        id: reader
        stdout: StdioCollector {
            onStreamFinished: {
                const levels = Ddc.parseLevels(text);
                const monitors = {};
                for (const d of root.detected) {
                    const l = levels[String(d.bus)];
                    if (l)
                        monitors[d.output] = {kind: "ddc", bus: d.bus, max: l.max, level: l.current / l.max};
                }
                root.replaceMonitors(monitors);
            }
        }
    }
    function replaceMonitors(monitors: var): void {
        const next = targets.builtin ? {builtin: targets.builtin} : {};
        targets = Object.assign(next, monitors);
    }
    Timer {
        id: redetect
        // Monitors need a moment after hotplug before they answer DDC/CI.
        interval: 2500
        onTriggered: {
            if (!detector.running)
                detector.running = true;
        }
    }
    Connections {
        target: Quickshell
        function onScreensChanged() { redetect.restart(); }
    }
}
