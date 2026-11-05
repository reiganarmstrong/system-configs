# Every NixOS host imports this. Hosts pick features through the `desktop`
# options rather than importing individual modules.
{ inputs, ... }:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ./theme.nix
    ./user.nix
    ./base.nix
    ./updates.nix
    ./desktop.nix
  ];
}
