# Hands-off updates. CI updates flake.lock weekly and commits it only after the
# laptop configuration builds; each machine pulls that commit daily and applies
# it at the next boot, so nothing changes under a running session.
{ config, lib, ... }:
let
  cfg = config.desktop.updates;
in
{
  options.desktop.updates = {
    enable = lib.mkEnableOption "daily automatic upgrades from the GitHub repository";
    flake = lib.mkOption {
      type = lib.types.str;
      default = "github:reiganarmstrong/system-configs";
      description = "Flake the machine upgrades from; the host name selects the configuration.";
    };
  };

  config = {
    system.autoUpgrade = lib.mkIf cfg.enable {
      enable = true;
      flake = "${cfg.flake}#${config.networking.hostName}";
      operation = "boot";
      dates = "daily";
      randomizedDelaySec = "45min";
      persistent = true;
      allowReboot = false;
    };

    # Old builds stay selectable in the boot menu for two weeks.
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };
}
