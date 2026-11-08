# Lowercase home folders. Apps find them through ~/.config/user-dirs.dirs;
# Flatpaks such as Zen are granted "xdg-download" and see only the folder
# named here, so without this file they have nowhere to save downloads.
{ config, lib, ... }:
let
  home = config.home.homeDirectory;
  sidebar = [
    "documents"
    "downloads"
    "music"
    "pictures"
    "videos"
  ];
in
{
  # Files lists its sidebar folders from the GTK bookmarks file. Write it
  # once rather than linking it, so bookmarks added in Files are kept.
  home.activation.filesSidebar = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    bookmarks=${config.xdg.configHome}/gtk-3.0/bookmarks
    if [ ! -e "$bookmarks" ]; then
      run mkdir -p "$(dirname "$bookmarks")"
      run tee "$bookmarks" >/dev/null <<'EOF'
    ${lib.concatMapStrings (name: "file://${home}/${name}\n") sidebar}EOF
    fi
  '';

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    # The desktop is the home folder itself, so no ~/desktop is created.
    desktop = home;
    documents = "${home}/documents";
    download = "${home}/downloads";
    music = "${home}/music";
    pictures = "${home}/pictures";
    videos = "${home}/videos";
    publicShare = null;
    templates = null;
    projects = null;
  };
}
