# Niri's configuration, generated from the shared theme and checked with
# `niri validate` at build time. Settings owns everything a user can change
# (input, gaps, corner radius, motion, cursor size, outputs): it writes those
# to settings.kdl in the state directory, which is included last. Niri
# reloads either file as soon as it changes.
{
  config,
  osConfig,
  lib,
  pkgs,
  ...
}:
let
  inherit (osConfig.desktop) theme;
  niri = osConfig.programs.niri.package;

  terminal = lib.getExe pkgs.ghostty;
  qs = lib.getExe' pkgs.quickshell "qs";
  cursor = config.home.pointerCursor.name;
  settingsFile = "${config.xdg.stateHome}/system-configs/settings.kdl";

  str = builtins.toJSON;
  # "#rrggbb" and an opacity from 0 to 1 -> "#rrggbbaa".
  rgba =
    hex: alpha:
    let
      byte = lib.toLower (lib.toHexString (builtins.floor (alpha * 255 + 0.5)));
    in
    hex + lib.optionalString (builtins.stringLength byte < 2) "0" + byte;
  # Shell commands for key bindings, as niri's quoted spawn arguments.
  shell =
    args:
    lib.concatMapStringsSep " " str (
      [
        qs
        "ipc"
        "call"
      ]
      ++ args
    );

  workspaceBinds = lib.concatMapStrings (
    i:
    let
      key = toString (lib.mod i 10);
    in
    "    Mod+${key} { focus-workspace ${toString i}; }\n"
    + "    Mod+Shift+${key} { move-column-to-workspace ${toString i}; }\n"
  ) (lib.range 1 10);

  configText = ''
    // Generated from nixos/modules/home/niri. Change the look in the NixOS
    // theme and user choices in Settings, not here.

    input {
        keyboard {
            numlock
        }
    }

    // Monochrome glass. Windows are opaque except Ghostty; the shell's bar,
    // popups, dock, notifications and OSD are translucent and ask for blur.
    layout {
        center-focused-column "never"
        always-center-single-column

        preset-column-widths {
            proportion 0.5
            proportion 0.66667
            proportion 1.0
        }
        default-column-width { proportion 1.0; }

        focus-ring {
            off
        }

        border {
            width 1
            active-color ${str (rgba theme.colors.accent theme.opacity.activeBorder)}
            inactive-color ${str (rgba theme.colors.accent theme.opacity.inactiveBorder)}
            urgent-color ${str theme.colors.urgent}
        }

        shadow {
            on
            softness ${toString theme.shadow.softness}
            spread ${toString theme.shadow.spread}
            offset x=0 y=${toString theme.shadow.offsetY}
            color ${str (rgba "#000000" theme.shadow.opacity)}
            inactive-color ${str (rgba "#000000" theme.shadow.inactiveOpacity)}
        }

        tab-indicator {
            width 3
            gap 6
            corner-radius 2
            active-color ${str (rgba theme.colors.accent 0.8)}
            inactive-color ${str (rgba theme.colors.accent 0.25)}
            urgent-color ${str theme.colors.urgent}
        }

        insert-hint {
            color ${str (rgba theme.colors.accent 0.15)}
        }

        // The shell's wallpaper sits on the backdrop (see the layer rule
        // below), so workspaces stay transparent and it does not scroll.
        background-color "transparent"
    }

    overview {
        backdrop-color ${str theme.colors.background}
        workspace-shadow {
            off
        }
    }

    // Every background blur, whether a client asks for it through
    // ext-background-effect or a rule below turns it on. Low saturation
    // keeps colourful content behind the glass from tinting it.
    blur {
        passes ${toString theme.blur.passes}
        offset ${toString theme.blur.offset}
        noise ${toString theme.blur.noise}
        saturation ${toString theme.blur.saturation}
    }

    prefer-no-csd

    cursor {
        xcursor-theme ${str cursor}
        hide-when-typing
    }

    screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

    hotkey-overlay {
        skip-at-startup
    }

    environment {
        TERMINAL ${str terminal}
        XCURSOR_THEME ${str cursor}
        QS_ICON_THEME ${str config.gtk.iconTheme.name}
        QT_QPA_PLATFORM "wayland;xcb"
        QT_WAYLAND_DISABLE_WINDOWDECORATION "1"
        ELECTRON_OZONE_PLATFORM_HINT "auto"
        NIXOS_OZONE_WL "1"
    }

    // The shell: bar, dock, launcher, notifications, OSD and lock screen.
    spawn-at-startup ${str qs}

    // Window rules. Later rules win, and settings.kdl adds the corner radius.
    window-rule {
        geometry-corner-radius ${toString theme.radius.window}
        clip-to-geometry true
    }

    // Apps that remember being maximized (Files does) open as a tiled column
    // instead of covering the screen.
    window-rule {
        open-maximized-to-edges false
    }

    // Ghostty is the one translucent app. Tiled windows never overlap, so the
    // cheap xray blur of the wallpaper is what would be behind it anyway.
    window-rule {
        match app-id="^com\\.mitchellh\\.ghostty$"
        draw-border-with-background false
        background-effect {
            blur true
        }
    }

    // Floating windows can overlap others, so blur what is really behind them.
    window-rule {
        match is-floating=true
        background-effect {
            xray false
        }
    }

    window-rule {
        match title="^(Open File|Open Folder|Save As|Save File|Choose Files?|Select a File)"
        open-floating true
    }

    // Settings is a normal movable window with a translucent fill.
    window-rule {
        match app-id="^org\\.quickshell$" title="^Settings$"
        open-floating true
        default-column-width { fixed 960; }
        default-window-height { fixed 680; }
        draw-border-with-background false
        background-effect {
            blur true
        }
    }

    window-rule {
        match app-id="^zen" title="^Picture-in-Picture$"
        open-floating true
    }

    window-rule {
        match app-id="^org\\.gnome\\.Calendar$"
        default-column-width { proportion 0.66667; }
    }

    // Keyring and polkit prompts stay out of screen recordings.
    window-rule {
        match app-id="^gcr-prompter$"
        match app-id="^org\\.gnome\\.keyring"
        match app-id="polkit"
        block-out-from "screencast"
    }

    // Stationary wallpaper on the backdrop, also shown behind the overview.
    layer-rule {
        match namespace="^shell-wallpaper$"
        place-within-backdrop true
    }

    // The shell asks for blur behind its glass. Turning xray off blurs the
    // windows behind it, not only the wallpaper.
    layer-rule {
        match namespace="^shell-"
        background-effect {
            xray false
        }
    }

    // Notifications and the OSD stay out of screen recordings.
    layer-rule {
        match namespace="^shell-(notifications|osd)$"
        block-out-from "screencast"
    }

    // Key bindings. Mod is Super; Mod+Shift+/ lists them all.
    binds {
        Mod+Shift+Slash { show-hotkey-overlay; }

        // Apps and shell.
        Mod+T hotkey-overlay-title="Terminal" { spawn ${str terminal}; }
        Mod+E hotkey-overlay-title="Files" { spawn "nautilus" "--new-window"; }
        Mod+Space hotkey-overlay-title="App search" { spawn ${
          shell [
            "launcher"
            "toggle"
          ]
        }; }
        Mod+Comma hotkey-overlay-title="Settings" { spawn ${
          shell [
            "settings"
            "toggle"
          ]
        }; }
        Mod+S hotkey-overlay-title="Control centre" { spawn ${
          shell [
            "control"
            "toggle"
          ]
        }; }
        Mod+Shift+V hotkey-overlay-title="Clipboard history" { spawn ${
          shell [
            "clipboard"
            "toggle"
          ]
        }; }
        Mod+L hotkey-overlay-title="Lock the screen" { spawn ${
          shell [
            "lock"
            "lock"
          ]
        }; }

        // Windows.
        Mod+Q repeat=false { close-window; }
        Mod+F { fullscreen-window; }
        Mod+Shift+F { maximize-column; }
        Mod+Ctrl+F { expand-column-to-available-width; }
        Mod+V { toggle-window-floating; }
        Mod+Shift+Tab { switch-focus-between-floating-and-tiling; }
        Mod+C { center-column; }
        Mod+W { toggle-column-tabbed-display; }
        Mod+R { switch-preset-column-width; }
        Mod+Shift+R { reset-window-height; }
        Mod+Minus { set-column-width "-10%"; }
        Mod+Equal { set-column-width "+10%"; }
        Mod+Shift+Minus { set-window-height "-10%"; }
        Mod+Shift+Equal { set-window-height "+10%"; }
        Mod+BracketLeft { consume-or-expel-window-left; }
        Mod+BracketRight { consume-or-expel-window-right; }
        Mod+O repeat=false { toggle-overview; }

        // Focus and move.
        Mod+Left { focus-column-left; }
        Mod+Right { focus-column-right; }
        Mod+Up { focus-window-or-workspace-up; }
        Mod+Down { focus-window-or-workspace-down; }
        Mod+Shift+Left { move-column-left; }
        Mod+Shift+Right { move-column-right; }
        Mod+Shift+Up { move-window-up-or-to-workspace-up; }
        Mod+Shift+Down { move-window-down-or-to-workspace-down; }
        Mod+Home { focus-column-first; }
        Mod+End { focus-column-last; }
        Mod+Shift+Home { move-column-to-first; }
        Mod+Shift+End { move-column-to-last; }

        // Monitors.
        Mod+Ctrl+Left { focus-monitor-left; }
        Mod+Ctrl+Right { focus-monitor-right; }
        Mod+Ctrl+Up { focus-monitor-up; }
        Mod+Ctrl+Down { focus-monitor-down; }
        Mod+Shift+Ctrl+Left { move-column-to-monitor-left; }
        Mod+Shift+Ctrl+Right { move-column-to-monitor-right; }
        Mod+Shift+Ctrl+Up { move-column-to-monitor-up; }
        Mod+Shift+Ctrl+Down { move-column-to-monitor-down; }

        // Workspaces.
        Mod+Page_Up { focus-workspace-up; }
        Mod+Page_Down { focus-workspace-down; }
        Mod+Shift+Page_Up { move-column-to-workspace-up; }
        Mod+Shift+Page_Down { move-column-to-workspace-down; }
        Mod+WheelScrollDown cooldown-ms=150 { focus-workspace-down; }
        Mod+WheelScrollUp cooldown-ms=150 { focus-workspace-up; }
        Mod+WheelScrollRight { focus-column-right; }
        Mod+WheelScrollLeft { focus-column-left; }
    ${workspaceBinds}
        // Screenshots save to ~/Pictures/Screenshots and copy to the clipboard.
        Print { screenshot; }
        Ctrl+Print { screenshot-screen; }
        Alt+Print { screenshot-window; }

        // Hardware keys go through the shell so it can show its OSD, and
        // work on the lock screen too.
        XF86AudioRaiseVolume allow-when-locked=true { spawn ${
          shell [
            "osd"
            "volume"
            "up"
          ]
        }; }
        XF86AudioLowerVolume allow-when-locked=true { spawn ${
          shell [
            "osd"
            "volume"
            "down"
          ]
        }; }
        XF86AudioMute allow-when-locked=true { spawn ${
          shell [
            "osd"
            "volume"
            "mute"
          ]
        }; }
        XF86MonBrightnessUp allow-when-locked=true { spawn ${
          shell [
            "osd"
            "brightness"
            "up"
          ]
        }; }
        XF86MonBrightnessDown allow-when-locked=true { spawn ${
          shell [
            "osd"
            "brightness"
            "down"
          ]
        }; }
        XF86AudioPlay allow-when-locked=true { spawn "playerctl" "play-pause"; }
        XF86AudioPause allow-when-locked=true { spawn "playerctl" "play-pause"; }
        XF86AudioNext allow-when-locked=true { spawn "playerctl" "next"; }
        XF86AudioPrev allow-when-locked=true { spawn "playerctl" "previous"; }

        // Escape hatches.
        Mod+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }
        Mod+Shift+P { power-off-monitors; }
        Ctrl+Alt+Delete { quit; }
    }

    // Settings' choices. Optional: missing until the first activation.
    include optional=true ${str settingsFile}
  '';

  validated =
    pkgs.runCommand "niri-config.kdl"
      {
        nativeBuildInputs = [ niri ];
        text = configText;
        passAsFile = [ "text" ];
      }
      ''
        cp $textPath $out
        niri validate -c $out
      '';
in
{
  xdg.configFile."niri/config.kdl".source = validated;
}
