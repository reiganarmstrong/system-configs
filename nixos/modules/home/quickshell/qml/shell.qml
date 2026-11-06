// The desktop shell. Per-screen surfaces are created for every monitor;
// popups are single instances that open on the focused screen.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules
import qs.services

ShellRoot {
    Variants {
        model: Quickshell.screens

        Scope {
            id: screenScope
            required property ShellScreen modelData

            Wallpaper { screen: screenScope.modelData }
            Bar { screen: screenScope.modelData }
            Dock { screen: screenScope.modelData }
        }
    }

    Settings {}
    ControlCenter { id: controlCenter }
    Dash {}
    Launcher {}
    ClipboardHistory {}
    NotificationPopups {}
    Osd { id: osd }
    Lock {}

    Component.onCompleted: {
        if (Theme.data.lockOnStart)
            Session.locked = true;
    }

    // `qs ipc call <target> <function> [args]`, used by Hyprland key bindings.
    IpcHandler {
        target: "settings"
        function open(page: string): void { ShellState.openSettings(page); }
        function toggle(): void {
            if (ShellState.settingsOpen) ShellState.settingsOpen = false;
            else ShellState.openSettings("appearance");
        }
        function status(): string {
            return JSON.stringify({open: ShellState.settingsOpen, page: ShellState.settingsPage,
                ready: Prefs.ready, saving: Prefs.saving, error: Prefs.error, values: Prefs.values,
                preview: Prefs.preview, brightnessAvailable: Brightness.available, brightness: Brightness.level});
        }
    }
    IpcHandler {
        target: "launcher"
        function toggle(): void { ShellState.toggle("launcher"); }
    }
    IpcHandler {
        target: "clipboard"
        function toggle(): void { ShellState.toggle("clipboard"); }
        function status(): string {
            return JSON.stringify({open: ShellState.openPanel === "clipboard", ready: Clipboard.ready,
                count: Clipboard.items.length, paused: Clipboard.paused, error: Clipboard.error});
        }
    }
    IpcHandler {
        target: "control"
        function toggle(): void { ShellState.toggle("control"); }
        function openPage(page: string): void {
            ShellState.openPanel = "control";
            controlCenter.openPage(page);
        }
        function status(): string {
            return JSON.stringify({open: controlCenter.open, visible: controlCenter.visible,
                page: controlCenter.page, shownPage: controlCenter.shownPage, width: controlCenter.full + 28});
        }
    }
    IpcHandler {
        target: "dash"
        function toggle(): void { ShellState.toggle("dash"); }
    }
    IpcHandler {
        target: "lock"
        function lock(): void { Session.lock(); }
    }
    IpcHandler {
        target: "session"
        function status(): string {
            return JSON.stringify({
                locked: Session.locked,
                caffeine: Session.caffeine,
                doNotDisturb: Notifs.doNotDisturb,
                openPanel: ShellState.openPanel,
                calendarDate: CalendarData.dayKey,
                calendarEvents: CalendarData.events.length,
            });
        }
        function caffeine(enabled: bool): void { Session.caffeine = enabled; }
    }
    IpcHandler {
        target: "osd"
        function volume(action: string): void {
            if (action === "up")
                Audio.setVolume(Audio.volume + 0.05);
            else if (action === "down")
                Audio.setVolume(Audio.volume - 0.05);
            else
                Audio.toggleMute();
            osd.show(Audio.icon, Audio.muted ? 0 : Audio.volume);
        }
        function brightness(action: string): void {
            Brightness.step(action === "up" ? 0.05 : -0.05);
            osd.show("sun", Brightness.level);
        }
    }
}
