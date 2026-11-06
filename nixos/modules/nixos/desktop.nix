# The Hyprland desktop: compositor, login, audio, hardware services and fonts.
# The look lives in the Home Manager modules; this provides what they run on.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.desktop;
  hyprland = config.programs.hyprland.package;
in
{
  options.desktop = {
    enable = lib.mkEnableOption "the Hyprland desktop";
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
        description = "Hyprland output name of the built-in display; empty matches any.";
      };
      mode = lib.mkOption {
        type = lib.types.str;
        default = "preferred";
        description = "Resolution and refresh rate, such as 2880x1920@120.";
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
        Start Hyprland for the user at boot without a login prompt. The shell
        locks the session immediately, so its lock screen acts as the login
        screen; disk encryption already asks for a password at boot.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.hyprland.enable = true;

    services.greetd = {
      enable = true;
      settings = {
        # Shown only after logging out.
        default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd start-hyprland";
      }
      // lib.optionalAttrs cfg.autoLogin {
        initial_session = {
          user = cfg.user;
          command = "${hyprland}/bin/start-hyprland";
        };
      };
    };

    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };

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
    security.pam.services.greetd.enableGnomeKeyring = true;
    # The Quickshell lock screen authenticates through this PAM service, which
    # also unlocks the login keyring that autologin leaves locked.
    security.pam.services.quickshell.enableGnomeKeyring = true;
    programs.dconf.enable = true;

    fonts = {
      packages = [
        (pkgs.google-fonts.override { fonts = [ "Manrope" ]; })
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

    environment.systemPackages = [
      pkgs.brightnessctl
      pkgs.playerctl
      pkgs.wl-clipboard
      pkgs.grim
      pkgs.slurp
      pkgs.hyprpicker
      pkgs.libnotify
      pkgs.gnome-keyring
      pkgs.networkmanagerapplet
    ];

    desktop.theme.wallpaper = lib.mkDefault (
      pkgs.runCommand "wallpaper.png" { nativeBuildInputs = [ pkgs.resvg ]; } ''
        resvg --width 3840 ${../../assets/wallpaper.svg} $out
      ''
    );
  };
}
