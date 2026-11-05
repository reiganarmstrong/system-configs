# The Quickshell desktop shell: bar, dock, control centre, notifications,
# launcher, lock screen and on-screen displays. The QML in ./qml is plain,
# hand-written code; Nix adds theme.json (from the shared theme) and
# icons.json (Lucide icon names to font codepoints) beside it.
{
  osConfig,
  lib,
  pkgs,
  ...
}:
let
  inherit (osConfig.desktop) theme;

  lucideInfo = pkgs.fetchurl {
    url = "https://unpkg.com/lucide-static@${pkgs.lucide.version}/font/info.json";
    hash = "sha256-pMCQj8aNGffODinmJdNFQ3x+4z7bcY1TpAq6uZuZUeY=";
  };

  config =
    pkgs.runCommand "quickshell-config"
      {
        nativeBuildInputs = [ pkgs.jq ];
        theme = builtins.toJSON (
          theme
          // {
            wallpaper = "${theme.wallpaper}";
            user = {
              name = osConfig.desktop.user;
              fullName = osConfig.desktop.fullName;
            };
            dock.pinned = osConfig.desktop.dock.pinned;
            lockOnStart = osConfig.desktop.autoLogin;
          }
        );
        passAsFile = [ "theme" ];
      }
      ''
        cp -r ${./qml} $out
        chmod -R u+w $out
        cp $themePath $out/theme.json
        # {"wifi": "", ...}: names to the glyphs Lucide's font draws.
        jq 'with_entries(.value = (.value.encodedCode | ltrimstr("\\") | "\\u" + .))' \
          ${lucideInfo} | sed 's/\\\\u/\\u/g' > $out/icons.json
      '';
in
{
  home.packages = [ pkgs.quickshell ];

  # The lock screen creates and unlocks the "login" keyring with the account
  # password. Marking it the default stops apps asking to create another.
  home.activation.defaultKeyring = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    keyrings="$HOME/.local/share/keyrings"
    if [ ! -e "$keyrings/default" ]; then
      run mkdir -p "$keyrings"
      run chmod 700 "$keyrings"
      run sh -c "printf login > '$keyrings/default'"
    fi
  '';
  xdg.configFile."quickshell".source = config;
}
