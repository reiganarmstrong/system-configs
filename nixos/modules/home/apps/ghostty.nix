# Ghostty: a translucent monochrome terminal that niri blurs behind.
{ osConfig, lib, ... }:
let
  theme = osConfig.desktop.theme;
  palette = builtins.fromJSON (builtins.readFile ./terminal-palette.json);
in
{
  programs.ghostty = {
    enable = true;
    settings = {
      font-family = theme.fonts.mono;
      font-size = 11;
      background = palette.background;
      foreground = palette.foreground;
      cursor-color = palette.cursor;
      cursor-text = palette.cursorText;
      selection-background = palette.selectionBg;
      selection-foreground = palette.selectionFg;
      background-opacity = 0.84;
      background-blur = true;
      window-padding-balance = true;
      mouse-hide-while-typing = true;
      shell-integration-features = "ssh-env";
      window-padding-x = 14;
      window-padding-y = 12;
      window-decoration = false;
      cursor-style = "bar";
      confirm-close-surface = false;
      palette = builtins.genList (
        i:
        let
          names = [
            "black"
            "red"
            "green"
            "yellow"
            "blue"
            "magenta"
            "cyan"
            "white"
          ];
          colors = if i < 8 then palette.normal else palette.bright;
        in
        "${toString i}=${colors.${builtins.elemAt names (lib.mod i 8)}}"
      ) 16;
    };
  };
}
