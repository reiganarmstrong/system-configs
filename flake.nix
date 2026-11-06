{
  description = "NixOS systems with Hyprland and a Quickshell desktop shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixos-hardware.inputs.nixpkgs.follows = "nixpkgs";
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      mkHost =
        name:
        nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = [
            ./nixos/modules/nixos
            ./nixos/hosts/${name}
          ];
        };
    in
    {
      nixosConfigurations = {
        framework = mkHost "framework";
        vm = mkHost "vm";
      };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-rfc-style;
      checks.${system} = {
        admin =
          let
            admin = nixpkgs.lib.findFirst (
              package: nixpkgs.lib.getName package == "desktop-admin"
            ) null (mkHost "vm").config.home-manager.users.reagan.home.packages;
          in
          admin.tests.admin;
        clipboardSelection = import ./nixos/tests/clipboard-selection {
          pkgs = nixpkgs.legacyPackages.${system};
        };
        media = import ./nixos/tests/media { pkgs = nixpkgs.legacyPackages.${system}; };
        dropdowns = import ./nixos/tests/dropdowns { pkgs = nixpkgs.legacyPackages.${system}; };
        settingsFailures = import ./nixos/tests/settings-failures {
          pkgs = nixpkgs.legacyPackages.${system};
          shellConfig = (mkHost "vm").config.home-manager.users.reagan.xdg.configFile."quickshell".source;
        };
        clipboard =
          (mkHost "vm").config.home-manager.users.reagan.services.desktop-clipboard.package.tests.clipboard;
        settings =
          let
            settings = nixpkgs.lib.findFirst (
              package: nixpkgs.lib.getName package == "desktop-settings"
            ) null (mkHost "vm").config.home-manager.users.reagan.home.packages;
          in
          settings.tests.settings;
        calendar =
          let
            calendar = nixpkgs.lib.findFirst (
              package: nixpkgs.lib.getName package == "desktop-calendar-events"
            ) null (mkHost "vm").config.home-manager.users.reagan.home.packages;
          in
          calendar.tests.calendar;
      };
    };
}
