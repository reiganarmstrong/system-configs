# Hyprland uses the shared shell and a separate writable HyprMod override.
{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}:
let
  rendered =
    builtins.replaceStrings
      [ "@TERMINAL@" "@SETTINGS@" "@CURSOR@" "@ICONS@" "@SCALE@" "@HYPRMOD@" ]
      [
        (lib.getExe pkgs.ghostty)
        "${config.xdg.stateHome}/system-configs/settings.lua"
        config.home.pointerCursor.name
        config.gtk.iconTheme.name
        (toString osConfig.desktop.display.scale)
        "${config.xdg.configHome}/hypr/hyprland-gui.lua"
      ]
      (builtins.readFile ./hyprland.lua);
in
{
  xdg.configFile."hypr/hyprland.lua".text = rendered;
  home.activation.hyprmodConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p ${config.xdg.configHome}/hypr
    # HyprMod replaces this file on every save, so it stays an ordinary
    # writable file outside the repo. It starts empty.
    if [ ! -e ${config.xdg.configHome}/hypr/hyprland-gui.lua ]; then
      run touch ${config.xdg.configHome}/hypr/hyprland-gui.lua
    fi
  '';
}
