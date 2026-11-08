# Settings changes are user state. Nix still supplies defaults and every tool.
{
  config,
  osConfig,
  lib,
  pkgs,
  ...
}:
let
  niri = osConfig.programs.niri.package;
  python = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);
  code = pkgs.runCommand "desktop-settings-python" { } ''
    mkdir -p $out
    cp ${./settings.py} $out/settings.py
    cp ${./admin.py} $out/admin.py
  '';
  defaults = pkgs.writeText "desktop-settings-defaults.json" (
    builtins.toJSON {
      clock24h = true;
      panelOpacity = osConfig.desktop.theme.opacity.panel;
      gaps = osConfig.desktop.theme.spacing.gaps;
      rounding = osConfig.desktop.theme.radius.window;
      cursorSize = config.home.pointerCursor.size;
      suspendMinutes = if osConfig.desktop.autoSuspend then 15 else 0;
    }
  );
  helper = pkgs.writeShellApplication {
    name = "desktop-settings";
    runtimeInputs = [
      pkgs.python3
      niri
      pkgs.hypridle
      pkgs.systemd
      pkgs.iproute2
      pkgs.dconf
    ];
    text = ''
      export DESKTOP_SETTINGS_DEFAULTS=${defaults}
      export DESKTOP_SETTINGS_FIXED_MODE=${if osConfig.desktop.display.fixedMode then "1" else "0"}
      export DESKTOP_SETTINGS_DISPLAY=${
        lib.escapeShellArg (builtins.toJSON { inherit (osConfig.desktop.display) output mode scale; })
      }
      export DESKTOP_CURSOR_NAME=${lib.escapeShellArg config.home.pointerCursor.name}
      exec python3 ${./settings.py} "$@"
    '';
    passthru.tests.settings =
      pkgs.runCommand "desktop-settings-tests"
        {
          # The tests check generated settings with the real `niri validate`.
          nativeBuildInputs = [
            pkgs.python3
            niri
          ];
        }
        ''
          python3 ${../../../tests/settings.py} ${./settings.py}
          touch $out
        '';
  };
  admin = pkgs.writeShellApplication {
    name = "desktop-admin";
    runtimeInputs = [
      python
      pkgs.systemd
      pkgs.glib
      pkgs.dconf
      pkgs.flatpak
      pkgs.cups
      pkgs.udisks2
      pkgs.tailscale
      pkgs.util-linux
      niri
      pkgs.quickshell
    ];
    text = ''
      export GI_TYPELIB_PATH=${pkgs.glib}/lib/girepository-1.0
      export LD_LIBRARY_PATH=${lib.makeLibraryPath [ pkgs.glib ]}
      export DESKTOP_SETTINGS_DEFAULTS=${defaults}
      export DESKTOP_CURSOR_NAME=${lib.escapeShellArg config.home.pointerCursor.name}
      export DESKTOP_ADMIN_CONFIG=${
        lib.escapeShellArg (
          builtins.toJSON {
            updates = osConfig.desktop.updates.enable;
            source = osConfig.desktop.updates.flake;
          }
        )
      }
      export DESKTOP_ADMIN_SYSTEMCTL=${pkgs.systemd}/bin/systemctl
      export DESKTOP_ADMIN_LPADMIN=${pkgs.cups}/bin/lpadmin
      exec python3 ${code}/admin.py "$@"
    '';
    passthru.tests.admin =
      pkgs.runCommand "desktop-admin-tests" { nativeBuildInputs = [ pkgs.python3 ]; }
        ''
          python3 ${../../../tests/admin.py} ${code}/admin.py
          touch $out
        '';
  };
  installApp = pkgs.writeShellApplication {
    name = "desktop-install-flatpak";
    runtimeInputs = [ pkgs.flatpak ];
    text = ''
      flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
      flatpak install --user --noninteractive flathub "$1"
    '';
  };
in
{
  services.hyprpolkitagent.enable = true;
  # Quickshell owns Wi-Fi password entry. A second secret agent keeps failed
  # joins waiting on a separate dialog hidden behind the control centre.
  xdg.configFile."autostart/nm-applet.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=NetworkManager Applet
    Hidden=true
  '';
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
    admin
    pkgs.pavucontrol
    pkgs.blueman
    pkgs.seahorse
    pkgs.gnome-disk-utility
    pkgs.wdisplays
    pkgs.nautilus
    pkgs.system-config-printer
  ];
  systemd.user.services."desktop-flatpak-install@".Service = {
    Type = "oneshot";
    ExecStart = "${installApp}/bin/desktop-install-flatpak %i";
    TimeoutStartSec = "30min";
  };
  systemd.user.services."desktop-flatpak-remove@".Service = {
    Type = "oneshot";
    ExecStart = "${pkgs.flatpak}/bin/flatpak uninstall --user --noninteractive %i";
    TimeoutStartSec = "10min";
  };
  systemd.user.services.desktop-flatpak-update.Service = {
    Type = "oneshot";
    ExecStart = "${pkgs.flatpak}/bin/flatpak update --user --noninteractive";
    TimeoutStartSec = "30min";
  };
  home.activation.userFlatpakExports = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p ${config.xdg.dataHome}/flatpak/exports/share/applications
  '';
  # Niri's settings.kdl and hypridle's idle.conf follow Nix default changes
  # (gaps, corner radius, the host display) without waiting for a save in
  # Settings. A rejected file is left as it was, so activation carries on.
  home.activation.desktopSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${helper}/bin/desktop-settings regenerate \
      || echo "desktop-settings: keeping the previous settings.kdl" >&2
  '';
  home.activation.desktopAppearance = lib.hm.dag.entryAfter [ "dconfSettings" ] ''
    if [ -S "/run/user/$(id -u)/bus" ]; then
      export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
      run ${helper}/bin/desktop-settings gtk-apply
    fi
  '';
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
