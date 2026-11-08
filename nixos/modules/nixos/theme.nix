# The single source for the desktop's look. Niri, Quickshell, GTK and the
# terminal all read these values, so restyling is one edit here.
{ lib, ... }:
let
  inherit (lib) mkOption types;
  color =
    default: description:
    mkOption {
      type = types.str;
      inherit default description;
    };
  number =
    default: description:
    mkOption {
      type = types.number;
      inherit default description;
    };
in
{
  options.desktop.theme = {
    colors = {
      # Monochrome glass: colour comes from the wallpaper and content.
      background = color "#0a0a0b" "Behind everything, where no wallpaper shows.";
      panel = color "#0a0a0b" "Fill of bars, docks and popups, before translucency.";
      tile = color "#ffffff" "Fill of controls inside panels, before translucency.";
      text = color "#ffffff" "Primary text and icons.";
      textDim = color "#a3a3a9" "Secondary text.";
      accent = color "#ffffff" "Active controls and the focused window border.";
      accentText = color "#0a0a0b" "Text and icons on the accent colour.";
      highlight = color "#626269" "Selected controls in Settings and slider fill.";
      urgent = color "#ff5c5c" "Errors and critical notifications.";
    };

    opacity = {
      panel = number 0.78 "Opacity of panel fills over the blurred background.";
      tile = number 0.1 "Opacity of control fills inside panels.";
      border = number 0.10 "Opacity of the white rim around panels and windows.";
      activeBorder = number 0.36 "Opacity of the rim around the focused window.";
      inactiveBorder = number 0.10 "Opacity of the rim around unfocused windows.";
    };

    radius = {
      window = number 14 "Window corner radius in logical pixels.";
      panel = number 22 "Corner radius of popups and the control centre.";
      tile = number 16 "Corner radius of controls inside panels.";
      pill = number 999 "Fully rounded ends for bar pills and sliders.";
    };

    spacing = {
      gaps = number 12 "Gap between windows, and between windows and the screen edge.";
      panel = number 14 "Padding inside panels.";
      tile = number 10 "Gap between controls inside panels.";
    };

    blur = {
      passes = number 3 "Blur passes; more is smoother and slower.";
      offset = number 3 "Sample spread per pass; higher is a wider blur.";
      noise = number 0.03 "Grain added to the blur so it doesn't band.";
      saturation = number 0.6 "Colour saturation through the blur; below 1 keeps the glass neutral.";
    };

    shadow = {
      softness = number 36 "Window shadow blur radius.";
      spread = number 2 "How far the shadow extends past the window.";
      offsetY = number 10 "Window shadow downward offset.";
      opacity = number 0.63 "Shadow opacity under the focused window.";
      inactiveOpacity = number 0.38 "Shadow opacity under unfocused windows.";
    };

    icons = mkOption {
      type = types.str;
      default = "Papirus-Dark";
      description = ''
        Base icon theme for apps, the launcher, the dock and Files. Images in
        nixos/icons/ are layered on top of it, so a file there replaces the
        theme's icon of the same name. Change iconPackage with it.
      '';
    };
    iconPackage = mkOption {
      type = types.str;
      default = "papirus-icon-theme";
      description = "The nixpkgs attribute that provides the icons theme.";
    };

    fonts = {
      ui = mkOption {
        type = types.str;
        default = "Inter";
        description = "Shell and application interface font.";
      };
      icons = mkOption {
        type = types.str;
        default = "lucide";
        description = "Symbol font for shell icons.";
      };
      mono = mkOption {
        type = types.str;
        default = "JetBrains Mono";
        description = "Terminal and code font.";
      };
      size = number 11 "Interface font size in points.";
    };

    wallpaper = mkOption {
      type = types.path;
      description = "Wallpaper image, as a PNG or JPEG.";
    };
  };
}
