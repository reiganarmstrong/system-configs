# GTK, icons, cursor and fonts for applications, matched to the shell.
{ osConfig, pkgs, ... }:
let
  theme = osConfig.desktop.theme;

  # Your own icons, layered over the base theme. Every folder in nixos/icons/
  # becomes a scalable icon directory, and the theme inherits the base one, so
  # an image named after an icon (apps/firefox.svg, places/folder.png)
  # replaces it and anything missing comes from the base theme.
  customIcons = pkgs.runCommand "custom-icon-theme" { } ''
    dest=$out/share/icons/Custom
    mkdir -p $dest
    dirs=""
    sections=""
    for dir in ${../../icons}/*/; do
      name=$(basename "$dir")
      mkdir -p "$dest/$name"
      find "$dir" -maxdepth 1 -type f \( -name '*.svg' -o -name '*.png' \) -exec cp {} "$dest/$name/" \;
      dirs="$dirs''${dirs:+,}$name"
      sections="$sections
    [$name]
    Size=64
    MinSize=8
    MaxSize=512
    Type=Scalable
    "
    done
    cat > $dest/index.theme <<EOF
    [Icon Theme]
    Name=Custom
    Comment=Images from nixos/icons over ${theme.icons}
    Inherits=${theme.icons},hicolor
    Directories=$dirs
    $sections
    EOF
  '';

  accentCss = ''
    @define-color accent_color ${theme.colors.highlight};
    @define-color accent_bg_color ${theme.colors.highlight};
    @define-color accent_fg_color #ffffff;
  '';
in
{
  home.pointerCursor = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
    hyprcursor.enable = true;
  };

  home.packages = [ pkgs.${theme.iconPackage} ];

  gtk = {
    enable = true;
    font = {
      name = theme.fonts.ui;
      size = theme.fonts.size;
    };
    iconTheme = {
      name = "Custom";
      package = customIcons;
    };
    # Dark mode for every GTK app, including plain GTK 4 ones like the volume
    # mixer, which otherwise default to light.
    colorScheme = "dark";
    # GTK 3 apps (Wi-Fi, Bluetooth, displays, passwords, disks) get the
    # libadwaita look that Files and Calendar already have, instead of GTK 3's
    # older built-in style. GTK 4 apps draw their own and stay unthemed.
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    gtk4.theme = null;
    # No window buttons in app title bars: windows close with Super+Q.
    gtk3.extraConfig.gtk-decoration-layout = ":";
    gtk4.extraConfig.gtk-decoration-layout = ":";
    # Selections and switches in the shell's blue rather than GNOME's.
    gtk3.extraCss = accentCss;
    gtk4.extraCss = accentCss;
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      icon-theme = "Custom";
      font-name = "${theme.fonts.ui} ${toString theme.fonts.size}";
      monospace-font-name = "${theme.fonts.mono} ${toString theme.fonts.size}";
    };
    # libadwaita apps (Files, Calendar) read their title-bar buttons from
    # here through the settings portal. Keep the separator with both sides
    # empty: Disks 46 assumes it exists and crashes on an empty string.
    "org/gnome/desktop/wm/preferences".button-layout = ":";
  };
}
