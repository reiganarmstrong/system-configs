# The user's desktop. Reads the shared theme from the NixOS configuration
# (`osConfig.desktop.theme`) so every program agrees on the look.
{ ... }:
{
  imports = [
    ./niri
    ./quickshell
    ./appearance.nix
    ./folders.nix
    ./idle.nix
    ./settings
    ./clipboard
    ./calendar
    ./apps
  ];

}
