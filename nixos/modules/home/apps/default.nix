# Applications and their styling.
{ pkgs, ... }:
{
  imports = [
    ./ghostty.nix
    ./shell.nix
    ./dev.nix
    ./monitor.nix
  ];

  # Bitwarden can leave a Flatpak process alive after its autostart service
  # stops. Match that service's grace period instead of delaying shutdown
  # for the scope's default 90 seconds.
  xdg.configFile."systemd/user/app-flatpak-com.bitwarden.desktop-.scope.d/10-shutdown.conf".text = ''
    [Scope]
    TimeoutStopSec=5s
  '';

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
