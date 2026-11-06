pragma Singleton
// History is owned by cliphist and supervised independently of the shell.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var items: []
    property bool paused: false
    property bool ready: false
    property string error: ""
    property var queue: []
    property string action: ""
    readonly property bool busy: worker.running
    readonly property bool mutating: worker.running && action !== "list"
    signal copied()

    function refresh() {
        if (!worker.running && queue.length === 0) enqueue(["list"]);
    }
    function copy(id: string) {
        if ((worker.running && action === "copy") || queue.some(command => command[0] === "copy")) return;
        enqueue(["copy", id]);
    }
    function remove(id: string) { enqueue(["delete", id]); }
    function clear() { enqueue(["clear"]); }
    function pause(on: bool) { enqueue(["pause", on ? "true" : "false"]); }
    function enqueue(command: var) {
        queue = [...queue, command];
        pump();
    }
    function pump() {
        if (worker.running || queue.length === 0) return;
        const command = queue[0];
        queue = queue.slice(1);
        action = command[0];
        worker.command = [Theme.data.programs.clipboard, ...command];
        worker.running = true;
    }
    Timer {
        interval: 750
        repeat: true
        running: ShellState.openPanel === "clipboard"
        onTriggered: root.refresh()
    }
    Process {
        id: worker
        property string output: ""
        stdout: StdioCollector { onStreamFinished: worker.output = text }
        onExited: (code, status) => {
            try {
                const data = JSON.parse(output);
                if (code !== 0 || data.error) {
                    root.error = data.error || "Clipboard history is unavailable.";
                } else {
                    root.error = "";
                    if (data.items !== undefined) {
                        root.items = data.items;
                        root.paused = data.paused;
                        root.ready = true;
                    }
                    if (data.copied) root.copied();
                }
            } catch (_) { root.error = "Clipboard history is unavailable."; }
            root.pump();
        }
    }
}
