pragma Singleton
// Niri's workspaces and focused output, from its IPC socket. One connection
// subscribes to the event stream; the other sends actions. Both speak niri's
// JSON protocol, one request or event per line.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string socketPath: Quickshell.env("NIRI_SOCKET") ?? ""
    // Every workspace: {id, idx, name, output, is_active, is_focused, is_urgent, active_window_id}.
    property var workspaces: []
    readonly property string focusedOutput: workspaces.find(w => w.is_focused)?.output ?? ""

    // The workspaces on one output, in order. Niri keeps an empty workspace at
    // the end of each output; it only shows while it's the active one.
    function workspacesOn(output: string): var {
        return workspaces
            .filter(w => w.output === output && (w.active_window_id !== null || w.is_active))
            .sort((a, b) => a.idx - b.idx);
    }
    function focusedScreen(): var {
        return Quickshell.screens.find(s => s.name === focusedOutput) ?? null;
    }

    function action(name: string, fields: var): void {
        if (!actions.connected)
            return;
        actions.write(JSON.stringify({Action: {[name]: fields ?? {}}}) + "\n");
        actions.flush();
    }
    function focusWorkspace(id: int): void {
        action("FocusWorkspace", {reference: {Id: id}});
    }
    function quit(): void {
        action("Quit", {skip_confirmation: true});
    }

    function handle(event: var): void {
        if (event.WorkspacesChanged) {
            workspaces = event.WorkspacesChanged.workspaces;
        } else if (event.WorkspaceActivated) {
            const {id, focused} = event.WorkspaceActivated;
            const output = workspaces.find(w => w.id === id)?.output;
            workspaces = workspaces.map(w => Object.assign({}, w, {
                is_active: w.output === output ? w.id === id : w.is_active,
                is_focused: focused ? w.id === id : w.is_focused,
            }));
        } else if (event.WorkspaceActiveWindowChanged) {
            const {workspace_id, active_window_id} = event.WorkspaceActiveWindowChanged;
            workspaces = workspaces.map(w => w.id === workspace_id
                ? Object.assign({}, w, {active_window_id}) : w);
        } else if (event.WorkspaceUrgencyChanged) {
            const {id, urgent} = event.WorkspaceUrgencyChanged;
            workspaces = workspaces.map(w => w.id === id ? Object.assign({}, w, {is_urgent: urgent}) : w);
        }
    }

    Socket {
        id: events
        path: root.socketPath
        connected: root.socketPath !== ""
        onConnectedChanged: {
            if (connected) {
                write("\"EventStream\"\n");
                flush();
            } else if (root.socketPath !== "") {
                reconnect.start();
            }
        }
        parser: SplitParser {
            onRead: line => {
                try {
                    root.handle(JSON.parse(line));
                } catch (error) {
                    console.warn("niri: unreadable event", error);
                }
            }
        }
    }

    Socket {
        id: actions
        path: root.socketPath
        connected: root.socketPath !== ""
        // Replies are {"Ok": ...} or {"Err": "..."}; only errors matter.
        parser: SplitParser {
            onRead: line => {
                if (line.startsWith("{\"Err\""))
                    console.warn("niri:", line);
            }
        }
    }

    // A dropped connection (niri restarting its IPC) is retried once a second.
    Timer {
        id: reconnect
        interval: 1000
        onTriggered: {
            events.connected = false;
            events.connected = true;
            actions.connected = false;
            actions.connected = true;
        }
    }
}
