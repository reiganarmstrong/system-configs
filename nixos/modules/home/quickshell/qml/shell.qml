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

    ControlCenter {}
    Dash {}
    Launcher {}
    NotificationPopups {}
    Osd { id: osd }
    Lock {}

    Component.onCompleted: {
        if (Theme.data.lockOnStart)
            Session.locked = true;
    }

    // `qs ipc call <target> <function> [args]`, used by Hyprland key bindings.
    IpcHandler {
        target: "launcher"
        function toggle(): void { ShellState.toggle("launcher"); }
    }
    IpcHandler {
        target: "control"
        function toggle(): void { ShellState.toggle("control"); }
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
