# System basics shared by every host: Nix itself, boot, locale and networking.
{ config, lib, ... }:
{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    trusted-users = [ "@wheel" ];
  };

  nixpkgs.hostPlatform = "x86_64-linux";
  nixpkgs.config.allowUnfree = true;

  boot.loader.systemd-boot = {
    enable = lib.mkDefault true;
    # Keeps the boot menu short; older builds remain until garbage collection.
    configurationLimit = 20;
  };
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

  networking.networkmanager.enable = true;
  services.tailscale = {
    enable = true;
    openFirewall = true;
    # Each machine signs in once; the desktop user can manage its connection.
    extraSetFlags = [ "--operator=${config.desktop.user}" ];
  };

  # timedated owns the mutable selection. Supply an initial zone only when
  # none exists, so changes in Settings survive rebuilds and reboots.
  time.timeZone = lib.mkDefault null;
  systemd.tmpfiles.rules = [ "L /etc/localtime - - - - /etc/zoneinfo/America/New_York" ];
  i18n.defaultLocale = "en_US.UTF-8";

  security.sudo.wheelNeedsPassword = true;

  # Release whose defaults this configuration was written against. Changing it
  # does not upgrade anything; see the NixOS manual before touching it.
  system.stateVersion = "26.05";
}
