# Settings changes are user state. Nix still supplies defaults and every tool.
{
  config,
  osConfig,
  lib,
  pkgs,
  ...
}:
let
  defaults = pkgs.writeText "desktop-settings-defaults.json" (
    builtins.toJSON {
      panelOpacity = osConfig.desktop.theme.opacity.panel;
      gaps = osConfig.desktop.theme.spacing.gapsIn;
      rounding = osConfig.desktop.theme.radius.window;
      suspendMinutes = if osConfig.desktop.autoSuspend then 15 else 0;
    }
  );
  helper = pkgs.writeShellApplication {
    name = "desktop-settings";
    runtimeInputs = [
      pkgs.python3
      pkgs.hyprland
      pkgs.hypridle
      pkgs.systemd
      pkgs.xdg-utils
      pkgs.iproute2
    ];
    text = ''
      export DESKTOP_SETTINGS_DEFAULTS=${defaults}
      export DESKTOP_SETTINGS_FIXED_MODE=${if osConfig.desktop.display.fixedMode then "1" else "0"}
      exec python3 ${./settings.py} "$@"
    '';
    passthru.tests.settings =
      pkgs.runCommand "desktop-settings-tests"
        {
          nativeBuildInputs = [ pkgs.python3 ];
        }
        ''
          python3 ${../../../tests/settings.py} ${./settings.py}
          touch $out
        '';
  };
in
{
  services.hyprpolkitagent.enable = true;
  # Pairing and authentication work without a traditional desktop's autostart.
  systemd.user.services.blueman-applet = {
    Unit = {
      Description = "Bluetooth pairing agent";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      ConditionPathExistsGlob = "/sys/class/bluetooth/hci*";
    };
    Service.ExecStart = "${pkgs.blueman}/bin/blueman-applet";
    Install.WantedBy = [ "graphical-session.target" ];
  };
  # Blueman is only the pairing agent here; the control centre already shows
  # connections, so drop its "Connected"/"Disconnected" notices.
  dconf.settings."org/blueman/general".plugin-list = [ "!ConnectionNotifier" ];
  home.packages = [
    helper
    pkgs.pavucontrol
    pkgs.blueman
    pkgs.seahorse
    pkgs.gnome-disk-utility
    pkgs.wdisplays
    pkgs.nautilus
  ];
  systemd.user.services.hypridle.Service.ExecStart = lib.mkForce [
    "${helper}/bin/desktop-settings idle-run"
  ];
  # hypridle 0.1.7 looks up its default config path even when given -c, and
  # aborts if nothing is there, so point that path at the generated file.
  xdg.configFile."hypr/hypridle.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${config.xdg.stateHome}/system-configs/idle.conf";
  xdg.desktopEntries.desktop-settings = {
    name = "Settings";
    comment = "Display, sound, appearance, keyboard, accounts and system preferences";
    icon = "preferences-system";
    exec = "${pkgs.quickshell}/bin/qs ipc call settings open appearance";
    categories = [
      "Settings"
      "DesktopSettings"
    ];
    settings.Keywords = "Display;Sound;Keyboard;Bluetooth;Wi-Fi;Power;";
    terminal = false;
  };
}
