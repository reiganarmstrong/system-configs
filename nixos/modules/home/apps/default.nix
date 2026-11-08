# Applications and their styling.
{ pkgs, ... }:
{
  imports = [
    ./ghostty.nix
    ./shell.nix
    ./dev.nix
    ./monitor.nix
  ];

  # The Flatpak browser receives index.html through the file portal without
  # the manual's CSS and other files. Open the complete online manual instead.
  xdg.desktopEntries.nixos-manual = {
    name = "NixOS Manual";
    comment = "Open the official NixOS manual";
    exec = "${pkgs.xdg-utils}/bin/xdg-open https://nixos.org/manual/nixos/stable/";
    icon = "nixos-manual";
    terminal = false;
    categories = [ "System" ];
  };
}
