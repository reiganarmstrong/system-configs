# The same pinned artwork as the Fedora Graphite profile. Extract the original
# PNG bytes from each ICNS file and verify them before publishing the theme.
{ pkgs, lib }:
let
  sources = builtins.fromJSON (builtins.readFile ./macos-sources.json);
  macos = map (
    icon:
    icon
    // {
      source = pkgs.fetchurl { inherit (icon) url sha256; };
    }
  ) sources.macos;
  official = map (
    icon:
    icon
    // {
      source = pkgs.fetchurl { inherit (icon) url sha256; };
      licenseFile = pkgs.fetchurl {
        url = icon.license_url;
        sha256 = icon.license_sha256;
      };
    }
  ) sources.official;
in
pkgs.runCommand "graphite-macos-icons" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  dest=$out/share/icons/Graphite-macOS-Light
  mkdir -p "$dest/1024x1024/apps"
  ${lib.concatMapStringsSep "\n" (icon: ''
    python ${./extract-icns.py} ${icon.source} "$dest/1024x1024/apps/${icon.name}.png"
    echo '${icon.png_sha256}  '"$dest/1024x1024/apps/${icon.name}.png" | sha256sum --check
  '') macos}
  ${lib.concatMapStringsSep "\n" (icon: ''
    cp ${icon.source} "$dest/1024x1024/apps/${icon.name}.png"
    cp ${icon.licenseFile} "$dest/${icon.name}-LICENSE.txt"
  '') official}
  cp ${./macos-sources.json} "$dest/SOURCES.json"
  cat > "$dest/index.theme" <<EOF
  [Icon Theme]
  Name=Graphite macOS Light
  Comment=Personal app artwork; source URLs, authors and hashes are in SOURCES.json
  Inherits=Papirus-Dark,Adwaita,hicolor
  Directories=1024x1024/apps

  [1024x1024/apps]
  Size=1024
  Context=Applications
  Type=Fixed
  EOF
''
