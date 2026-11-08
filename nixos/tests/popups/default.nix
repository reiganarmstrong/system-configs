# Popup geometry, card lifetime and launcher scrolling use real Wayland objects.
{ pkgs, shellConfig }:
pkgs.runCommand "shell-popup-tests"
  {
    nativeBuildInputs = [
      pkgs.quickshell
      pkgs.sway
      pkgs.dbus
      pkgs.libnotify
    ];
    FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
  }
  ''
    cp -r ${shellConfig} config
    chmod -R u+w config
    cp ${./shell.qml} config/shell.qml
    mkdir bin
    mkdir -p data/applications
    for i in $(seq -w 1 60); do
      cat > "data/applications/launcher-fixture-$i.desktop" <<APP
    [Desktop Entry]
    Type=Application
    Name=Launcher fixture $i
    Exec=true
    Icon=application-x-executable
    APP
    done
    cat > bin/desktop-settings <<'HELPER'
    #!/bin/sh
    printf '%s\n' '{"preferences":{},"defaults":{},"monitors":[],"system":{}}'
    HELPER
    chmod +x bin/desktop-settings
    patchShebangs bin
    export PATH="$PWD/bin:$PATH" HOME="$PWD" XDG_RUNTIME_DIR="$PWD/runtime"
    export XDG_DATA_HOME="$PWD/data"
    mkdir -m 700 runtime
    cat > sway.conf <<'CONFIG'
    output * mode 1440x960
    seat * fallback true
    CONFIG
    cat > run <<'SCRIPT'
    set -euo pipefail
    export WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1
    sway -c "$PWD/sway.conf" > sway.log 2>&1 &
    compositor_pid=$!
    trap 'kill "$compositor_pid" 2>/dev/null || true' EXIT
    for i in $(seq 30); do
      test -S "$XDG_RUNTIME_DIR/wayland-1" && break
      sleep 0.1
    done
    export WAYLAND_DISPLAY=wayland-1 QT_QPA_PLATFORM=wayland QT_QUICK_BACKEND=software
    timeout 10 qs -p "$PWD/config" 2>&1 | tee log
    grep -q 'PASSED: notification blur' log
    SCRIPT
    dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- bash run
    touch $out
  ''
