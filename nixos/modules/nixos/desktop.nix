# The Niri desktop: compositor, login, audio, hardware services and fonts.
# The look lives in the Home Manager modules; this provides what they run on.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.desktop;
  niri = config.programs.niri.package;
in
{
  options.desktop = {
    enable = lib.mkEnableOption "the Niri desktop";
    suspendSupported = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether the desktop can reliably suspend and resume on this machine.";
    };
    autoSuspend = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Suspend after fifteen minutes idle; disabled for the VNC test VM.";
    };
    display = {
      fixedMode = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Keep the physical output mode fixed when the virtual GPU cannot restore it reliably.";
      };
      output = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Niri output name of the built-in display, as `niri msg outputs` prints it; empty leaves every output automatic.";
      };
      mode = lib.mkOption {
        type = lib.types.str;
        default = "preferred";
        description = ''
          Resolution, such as 2880x1920, or "preferred". Niri picks the
          highest refresh rate for it. A refresh rate needs Niri's exact
          value, such as 2880x1920@120.000, so Settings is the easier place
          to choose one.
        '';
      };
      scale = lib.mkOption {
        type = lib.types.number;
        default = 1;
        description = "Display scale factor.";
      };
    };
    dock.pinned = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "com.mitchellh.ghostty"
        "app.zen_browser.zen"
        "t3code"
      ];
      description = "Desktop entry IDs always shown in the dock, in order.";
    };
    autoLogin = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Start Niri for the user at boot without a login prompt. The shell
        locks the session immediately, so its lock screen acts as the login
        screen; disk encryption already asks for a password at boot.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.niri.enable = true;
    # NixOS gives every unit TZDIR=<tzdata store path>. Flatpak names the
    # sandbox's zone by stripping TZDIR from /etc/localtime's target
    # (/etc/zoneinfo/…), so with the store path every app niri starts runs
    # in UTC. /etc/zoneinfo is the same complete database.
    systemd.user.services.niri.environment.TZDIR = lib.mkForce "/etc/zoneinfo";

    services.greetd = {
      enable = true;
      settings = {
        # Shown only after logging out.
        default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd niri-session";
      }
      // lib.optionalAttrs cfg.autoLogin {
        initial_session = {
          user = cfg.user;
          command = "${niri}/bin/niri-session";
        };
      };
    };

    # The Niri module sets up the portals: GNOME's for screencasts and for
    # open and save dialogs (shown in Files), GTK's for the rest.

    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    hardware.bluetooth.enable = true;
    services.blueman.enable = true;
    services.power-profiles-daemon.enable = true;
    services.upower.enable = true;
    # Trash, drives and network locations in Files.
    services.gvfs.enable = true;
    services.gnome.gnome-keyring.enable = true;
    services.gnome.gnome-online-accounts.enable = true;
    services.gnome.evolution-data-server = {
      enable = true;
      # Microsoft 365 / Outlook calendars use the Graph backend in this plugin.
      plugins = [ pkgs.evolution-ews ];
    };
    services.gnome.glib-networking.enable = true;
    services.printing.enable = true;
    services.avahi = {
      enable = true;
      nssmdns4 = true;
    };
    security.pam.services.greetd.enableGnomeKeyring = true;
    # The Quickshell lock screen authenticates through this PAM service, which
    # also unlocks the login keyring that autologin leaves locked.
    services.fprintd.enable = true;
    # Keep typed-password unlock immediate. The lock screen starts a separate
    # fingerprint conversation on request, so a missing reader never delays it.
    security.pam.services.quickshell = {
      enableGnomeKeyring = true;
      fprintAuth = false;
    };
    security.pam.services.quickshell-fingerprint = {
      unixAuth = false;
      fprintAuth = true;
    };
    programs.dconf.enable = true;

    fonts = {
      packages = [
        (pkgs.google-fonts.override { fonts = [ cfg.theme.fonts.ui ]; })
        pkgs.lucide
        pkgs.jetbrains-mono
        pkgs.noto-fonts
        pkgs.noto-fonts-color-emoji
      ];
      fontconfig.defaultFonts = {
        sansSerif = [ cfg.theme.fonts.ui ];
        monospace = [ cfg.theme.fonts.mono ];
        emoji = [ "Noto Color Emoji" ];
      };
    };

    # External monitors' brightness over DDC/CI; members of the i2c group can
    # reach /dev/i2c-*. The shell's brightness keys use ddcutil for them.
    hardware.i2c.enable = true;

    environment.systemPackages = [
      pkgs.brightnessctl
      pkgs.ddcutil
      pkgs.playerctl
      pkgs.wl-clipboard
      pkgs.libnotify
      pkgs.gnome-keyring
      pkgs.networkmanagerapplet
      # Niri starts it on demand so X11-only apps can open windows.
      pkgs.xwayland-satellite
    ];

    desktop.theme.wallpaper = lib.mkDefault ../../assets/nixos-framework.png;
  };
}
