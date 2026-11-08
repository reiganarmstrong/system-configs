# Framework Laptop 13 Pro, Intel Core Ultra 5 325.
{ inputs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.framework-intel-core-ultra-series3
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./hardware.nix
  ];

  networking.hostName = "framework";

  desktop = {
    enable = true;
    updates.enable = true;
    display = {
      output = "eDP-1";
      mode = "2880x1920";
      scale = 2;
    };
  };
}
