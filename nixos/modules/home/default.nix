# The user's desktop. Reads the shared theme from the NixOS configuration
# (`osConfig.desktop.theme`) so every program agrees on the look.
{ ... }:
{
  imports = [
    ./hyprland
    ./quickshell
    ./appearance.nix
    ./apps
  ];

}
