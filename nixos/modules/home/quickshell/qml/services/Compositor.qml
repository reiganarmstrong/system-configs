pragma Singleton
// Hyprland workspaces, focused output and session actions for the shell.
import Quickshell
import Quickshell.Hyprland as Hypr

Singleton {
    readonly property string focusedOutput: Hypr.Hyprland.focusedMonitor?.name ?? ""
    function focusedScreen(): var {
        return Quickshell.screens.find(s => s.name === focusedOutput) ?? Quickshell.screens[0] ?? null;
    }
    function workspacesOn(output: string): var {
        return Hypr.Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor?.name === output).map(w => ({
            id: w.id, idx: w.id, name: w.name, is_active: w.active, is_focused: w.focused,
            is_urgent: w.urgent, active_window_id: w.toplevels.values.length ? 1 : null,
        }));
    }
    function focusWorkspace(id: int): void {
        Quickshell.execDetached(["desktop-compositor", "focus-workspace", String(id)]);
    }
    function quit(): void {
        Quickshell.execDetached(["desktop-compositor", "quit"]);
    }
}
