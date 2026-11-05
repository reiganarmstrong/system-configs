# Hyprland's Lua configuration. The Lua files in ./lua hold the structure; the
# values that come from Nix (theme, display, program paths) arrive as a
# generated `nix.lua` table, so restyling never means editing Lua.
{
  osConfig,
  lib,
  pkgs,
  ...
}:
let
  inherit (osConfig.desktop) theme display;
  generated = {
    inherit theme;
    display = {
      inherit (display) output mode scale;
    };
    programs = {
      terminal = lib.getExe pkgs.ghostty;
      shell = lib.getExe' pkgs.quickshell "qs";
      cursor = "Bibata-Modern-Classic";
    };
  };
in
{
  xdg.configFile = {
    "hypr/nix.lua".text = "return " + lib.generators.toLua { } (generated // {
      theme = builtins.removeAttrs theme [ "wallpaper" ];
    });
  }
  // lib.mapAttrs' (name: _: lib.nameValuePair "hypr/${name}" { source = ./lua/${name}; }) (
    builtins.readDir ./lua
  );
}
