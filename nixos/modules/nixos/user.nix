# The one person using the machine, and the Home Manager profile they get.
{ config, lib, ... }:
let
  cfg = config.desktop;
in
{
  options.desktop = {
    user = lib.mkOption {
      type = lib.types.str;
      default = "reagan";
      description = "Login name of the machine's user.";
    };
    fullName = lib.mkOption {
      type = lib.types.str;
      default = "Reagan Armstrong";
      description = "Display name shown on the lock screen and control centre.";
    };
  };

  config = {
    users.users.${cfg.user} = {
      isNormalUser = true;
      description = cfg.fullName;
      extraGroups = [
        "wheel"
        "networkmanager"
        "video"
        "input"
      ];
    };

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      # A file Home Manager would overwrite is moved aside instead of failing activation.
      backupFileExtension = "hm-backup";
      users.${cfg.user} = {
        imports = [ ../home ];
        home.stateVersion = config.system.stateVersion;
      };
    };
  };
}
