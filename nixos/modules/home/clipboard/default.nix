# cliphist is the clipboard storage engine; Quickshell provides its picker.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  python = pkgs.python3.withPackages (p: [ p.pillow ]);
  helper = pkgs.writeShellApplication {
    name = "desktop-clipboard";
    runtimeInputs = [
      python
      pkgs.cliphist
      pkgs.wl-clipboard
    ];
    text = ''
      umask 077
      exec python3 ${./history.py} "$@"
    '';
    passthru.tests.clipboard =
      pkgs.runCommand "desktop-clipboard-tests"
        {
          nativeBuildInputs = [
            python
            pkgs.cliphist
          ];
        }
        ''
          python3 ${../../../tests/clipboard.py} ${./history.py}
          touch $out
        '';
  };
  watcher = type: {
    Unit = {
      Description = "Clipboard history (${type})";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type ${type} --watch ${config.services.desktop-clipboard.package}/bin/desktop-clipboard store";
      Restart = "on-failure";
      RestartSec = 1;
      UMask = "0077";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
in
{
  options.services.desktop-clipboard.package = lib.mkOption {
    type = lib.types.package;
    default = helper;
    internal = true;
    description = "Clipboard history adapter used by the desktop shell.";
  };
  config = {
    home.packages = [
      config.services.desktop-clipboard.package
      pkgs.cliphist
    ];
    systemd.user.services = {
      desktop-clipboard-text = watcher "text";
      desktop-clipboard-image = watcher "image";
    };
    xdg.desktopEntries.clipboard-history = {
      name = "Clipboard history";
      comment = "Search and recall copied text and images";
      icon = "edit-paste";
      exec = "${pkgs.quickshell}/bin/qs ipc call clipboard toggle";
      categories = [ "Utility" ];
      terminal = false;
    };
  };
}
