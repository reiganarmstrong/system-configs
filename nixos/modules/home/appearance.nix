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
    gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
  };

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    font-name = "${theme.fonts.ui} ${toString theme.fonts.size}";
    monospace-font-name = "${theme.fonts.mono} ${toString theme.fonts.size}";
  };
}
