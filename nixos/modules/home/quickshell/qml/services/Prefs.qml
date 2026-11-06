pragma Singleton
// The helper validates and atomically saves preferences, then applies them.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var values: ({})
    property var defaults: ({})
    property var monitors: []
    property var system: ({})
    property bool ready: false
    property string error: ""
    // The action that produced `error`; a resync after a failed save must not clear it.
    property string errorAction: ""
    property bool dirty: false
    property var queue: []
    property string action: ""
    property int revision: 0
    property int sentRevision: 0
    property var preview: ({})
    property int previewSeconds: 0
    readonly property bool saving: worker.running || saveDelay.running

    function get(key: string, fallback: var): var { return values[key] ?? fallback; }
    function set(key: string, value: var) {
        if (!ready) return;
        const updated = Object.assign({}, values);
        updated[key] = value;
        values = updated;
        revision++;
        dirty = true;
        error = "";
        saveDelay.restart();
    }
    function enqueue(command: var) {
        queue = [...queue, command];
        pump();
    }
    function refresh() { enqueue(["get"]); }
    function reset() { enqueue(["reset"]); }
    function displayPreview(config: var) { enqueue(["display-preview", JSON.stringify(config)]); }
    function displayKeep() { enqueue(["display-keep", preview.token]); }
    function displayRevert() { enqueue(["display-revert", preview.token]); }
    function pump() {
        if (worker.running) return;
        let command;
        if (dirty && !saveDelay.running) {
            dirty = false;
            sentRevision = revision;
            command = ["save", JSON.stringify(values)];
        } else if (queue.length) {
            command = queue[0];
            queue = queue.slice(1);
        } else return;
        action = command[0];
        worker.command = ["desktop-settings", ...command];
        worker.running = true;
    }
    Timer { id: saveDelay; interval: 200; onTriggered: root.pump() }
    Timer {
        interval: 1000
        running: root.previewSeconds > 0
        repeat: true
        onTriggered: {
            root.previewSeconds--;
            if (root.previewSeconds === 0 && root.preview.token)
                root.displayRevert();
        }
    }
    Process {
        id: worker
        property string output: ""
        stdout: StdioCollector { onStreamFinished: worker.output = text }
        onExited: (code, status) => {
            try {
                const result = JSON.parse(output);
                if (code !== 0 || result.error) {
                    root.error = result.error || "Settings could not be applied.";
                    root.errorAction = root.action;
                    if (root.action === "save" && root.revision === root.sentRevision)
                        root.queue = [...root.queue, ["get"]];
                } else {
                    if (root.action !== "get" || root.errorAction === "get")
                        root.error = "";
                    if (root.action === "get") {
                        if (!root.dirty) root.values = result.preferences;
                        root.defaults = result.defaults;
                        root.monitors = result.monitors;
                        root.system = result.system;
                        root.ready = true;
                    } else if (root.action === "reset") {
                        root.values = result.preferences;
                    } else if (root.action === "display-preview") {
                        root.preview = result;
                        root.previewSeconds = 15;
                    } else if (root.action.startsWith("display-")) {
                        root.preview = ({});
                        root.previewSeconds = 0;
                        root.queue = [...root.queue, ["get"]];
                    }
                }
            } catch (e) {
                root.error = "Settings could not be read. " + e;
                root.errorAction = root.action;
            }
            root.pump();
        }
    }
    Component.onCompleted: refresh()
}
