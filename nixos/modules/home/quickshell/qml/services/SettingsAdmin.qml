pragma Singleton
// Administrative requests in two serialized lanes. Read-only snapshots never
// wait behind a change that is waiting for authentication or a slow search,
// while changes still run one at a time in the order they were made.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var data: ({})
    property string error: ""
    // Neutral feedback, such as a cancelled authentication prompt.
    property string notice: ""
    // Snapshot requests a finished change is still waiting for, so controls
    // stay disabled until they show the state the change produced.
    property var settling: []
    property int lastId: 0
    readonly property bool busy: reads.active || changes.active
    readonly property bool mutating: changes.active || settling.length > 0
    readonly property string activity: changes.active && changes.current.action === "app-search" ? "Searching…" : mutating ? "Applying…" : ""
    readonly property var readActions: ["snapshot", "app-detail"]

    function get(section: string, fallback: var): var {
        return data[section] ?? fallback;
    }
    function refresh(section: string): int {
        // A running snapshot may predate a change, so only queued ones are shared.
        const queued = reads.queue.find(r => r.action === "snapshot" && r.payload.section === section);
        return queued ? queued.id : enqueue(reads, "snapshot", {
            section
        });
    }
    function request(action: string, payload: var): void {
        if (readActions.includes(action)) {
            enqueue(reads, action, payload);
            return;
        }
        error = "";
        notice = "";
        enqueue(changes, action, payload);
    }
    function enqueue(lane: var, action: string, payload: var): int {
        lastId++;
        lane.queue = [...lane.queue, {
                id: lastId,
                action,
                payload
            }];
        lane.pump();
        return lastId;
    }
    function finish(lane: var, code: int): void {
        const request = lane.current;
        let result;
        try {
            result = JSON.parse(lane.output);
        } catch (e) {
            result = {
                error: "Settings did not receive a valid response."
            };
        }
        const failed = code !== 0 || !!result.error;
        if (readActions.includes(request.action)) {
            settling = settling.filter(id => id !== request.id);
            // A failed refresh must not replace the error of the change before it.
            if (failed && !error)
                error = result.error || "Settings could not be loaded.";
        } else if (failed) {
            if (result.cancelled)
                notice = result.error;
            else
                error = result.error || "This change could not be applied.";
        } else {
            error = "";
            notice = result.notice ?? "";
        }
        if (!failed && result.section) {
            const next = Object.assign({}, data);
            next[result.section] = result.data;
            data = next;
        }
        // Failed changes can still have changed something; re-read either way.
        const ids = (result.refresh ?? []).map(section => refresh(section));
        if (!readActions.includes(request.action))
            settling = [...settling, ...ids];
    }

    component Lane: Process {
        id: lane
        property var queue: []
        property var current: ({
                id: 0,
                action: "",
                payload: ({})
            })
        property string output: ""
        // Set before the process starts; `running` only turns true once it has.
        property bool active: false
        signal finished(int code)
        function pump(): void {
            if (active || queue.length === 0)
                return;
            active = true;
            current = queue[0];
            queue = queue.slice(1);
            output = "";
            stdinEnabled = true;
            command = ["desktop-admin", current.action];
            running = true;
        }
        onStarted: {
            write(JSON.stringify(current.payload));
            stdinEnabled = false;
        }
        stdout: StdioCollector {
            onStreamFinished: lane.output = text
        }
        onExited: code => {
            active = false;
            finished(code);
            pump();
        }
    }
    Lane {
        id: reads
        onFinished: code => root.finish(reads, code)
    }
    Lane {
        id: changes
        onFinished: code => root.finish(changes, code)
    }
}
