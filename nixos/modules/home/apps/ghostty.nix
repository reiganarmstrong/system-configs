# Ghostty: a translucent monochrome terminal that Hyprland blurs behind.
{ osConfig, ... }:
let
  theme = osConfig.desktop.theme;
in
{
  programs.ghostty = {
    enable = true;
    settings = {
      font-family = theme.fonts.mono;
      font-size = 11;
      background = "#16161a";
      foreground = "#e6e6ea";
      background-opacity = 0.82;
      window-padding-x = 14;
      window-padding-y = 12;
      window-decoration = false;
      cursor-style = "bar";
      confirm-close-surface = false;
      palette = [
        "0=#2a2a30"
        "1=#e06c75"
        "2=#98c379"
        "3=#e5c07b"
        "4=#82aaff"
        "5=#c792ea"
        "6=#89ddff"
        "7=#d4d4d8"
        "8=#5c5c66"
        "9=#ff7a85"
        "10=#b5e08f"
        "11=#f2d394"
        "12=#a3c2ff"
        "13=#d9adf2"
        "14=#a8e8ff"
        "15=#ffffff"
      ];
    };
  };
}
