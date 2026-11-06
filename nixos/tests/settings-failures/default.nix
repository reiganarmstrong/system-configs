# Production Settings services and controls under headless Quickshell, with
# fake helpers that fail, refuse and wait like real ones.
{ pkgs, shellConfig }:
pkgs.runCommand "settings-failure-tests"
  {
    nativeBuildInputs = [
      pkgs.quickshell
      pkgs.python3
    ];
    LC_ALL = "C.UTF-8";
    QT_QPA_PLATFORM = "offscreen";
    QT_QUICK_BACKEND = "software";
    FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
  }
  ''
    cp -r ${shellConfig} config
    chmod -R u+w config
    cp ${./shell.qml} config/shell.qml
    mkdir bin state
    cp ${./desktop-settings} bin/desktop-settings
    cp ${./desktop-admin} bin/desktop-admin
    chmod +x bin/*
    patchShebangs bin
    export PATH="$PWD/bin:$PATH" FAKE_STATE="$PWD/state" HOME="$PWD" XDG_RUNTIME_DIR="$PWD/runtime"
    mkdir -m 700 runtime
    timeout 60 qs -p config/shell.qml 2>&1 | tee log
    grep -q '^.*PASSED' log
    touch $out
  ''
