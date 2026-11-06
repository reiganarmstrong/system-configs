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
  # Hyprland is started directly, so nothing marks the graphical session as
  # running. This target does, and autostart.lua starts it; user services
  # tied to the session (hypridle) start with it.
  systemd.user.targets.hyprland-session.Unit = {
    Description = "Hyprland session";
    BindsTo = [ "graphical-session.target" ];
    Wants = [ "graphical-session-pre.target" ];
    After = [ "graphical-session-pre.target" ];
  };

  xdg.configFile = {
    "hypr/nix.lua".text = "return " + lib.generators.toLua { } (generated // {
      theme = builtins.removeAttrs theme [ "wallpaper" ];
    });
  }
  // lib.mapAttrs' (name: _: lib.nameValuePair "hypr/${name}" { source = ./lua/${name}; }) (
    builtins.readDir ./lua
  );
}
