# GTK, icons, cursor and fonts for applications, matched to the shell.
{ osConfig, pkgs, ... }:
let
  theme = osConfig.desktop.theme;
in
{
  home.pointerCursor = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
    hyprcursor.enable = true;
  };

  gtk = {
    enable = true;
    font = {
      name = theme.fonts.ui;
      size = theme.fonts.size;
    };
    iconTheme = {
      name = "Colloid-Grey-Dark";
      package = pkgs.colloid-icon-theme.override { colorVariants = [ "grey" ]; };
    };
    # No window buttons in app title bars: windows close with Super+Q.
    gtk3.extraConfig.gtk-decoration-layout = ":";
    gtk4.extraConfig.gtk-decoration-layout = ":";
    gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      font-name = "${theme.fonts.ui} ${toString theme.fonts.size}";
      monospace-font-name = "${theme.fonts.mono} ${toString theme.fonts.size}";
    };
    # libadwaita apps (Files, Calendar) read their title-bar buttons from
    # here through the settings portal; empty means no close button.
    "org/gnome/desktop/wm/preferences".button-layout = "";
  };
}
