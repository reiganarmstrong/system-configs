{
  pkgs,
  lib,
  osConfig,
  ...
}:
let
  python = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);
  libraries = with pkgs; [
    evolution-data-server
    libical
    glib
    libsoup_3
    libsecret
    json-glib
    gnome-online-accounts
    gobject-introspection
  ];
  typelibPath = lib.makeSearchPath "lib/girepository-1.0" libraries;
  libraryPath = lib.makeLibraryPath libraries;
  calendarApp = pkgs.symlinkJoin {
    name = "gnome-calendar-with-timezones";
    paths = [ pkgs.gnome-calendar ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    # GNOME's timezone monitor needs the complete database, rather than the
    # system's selected-zone directory. This wraps the packaged app unchanged.
    postBuild = ''
      wrapProgram "$out/bin/gnome-calendar" --set TZDIR ${pkgs.tzdata}/share/zoneinfo
      desktop="$out/share/applications/org.gnome.Calendar.desktop"
      cp --remove-destination ${pkgs.gnome-calendar}/share/applications/org.gnome.Calendar.desktop "$desktop"
      chmod u+w "$desktop"
      substituteInPlace "$desktop" \
        --replace-quiet '${pkgs.gnome-calendar}/bin/gnome-calendar' "$out/bin/gnome-calendar"
    '';
  };
  calendarTest =
    pkgs.runCommand "calendar-events-check"
      {
        nativeBuildInputs = [
          python
          pkgs.dbus
        ];
        GI_TYPELIB_PATH = typelibPath;
        LD_LIBRARY_PATH = libraryPath;
        TZDIR = "${pkgs.tzdata}/share/zoneinfo";
        XDG_DATA_DIRS = "${pkgs.evolution-data-server}/share";
      }
      ''
        test_dir=$(mktemp -d "$TMPDIR/calendar-test-XXXXXX")
        export XDG_DATA_HOME="$test_dir/data"
        export XDG_CONFIG_HOME="$test_dir/config"
        export XDG_CACHE_HOME="$test_dir/cache"
        export TZ=UTC
        dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- \
          python3 ${../../../tests/calendar_events.py} ${./events.py}
        touch "$out"
      '';
  calendarEvents =
    (pkgs.writeShellApplication {
      name = "desktop-calendar-events";
      runtimeInputs = [ python ];
      text = ''
        export GI_TYPELIB_PATH="${typelibPath}''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
        export LD_LIBRARY_PATH="${libraryPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        export DESKTOP_CALENDAR_TIME_ZONE=${lib.escapeShellArg osConfig.time.timeZone}
        exec python3 ${./events.py} "$@"
      '';
    }).overrideAttrs
      (old: {
        passthru = (old.passthru or { }) // {
          tests.calendar = calendarTest;
        };
      });
in
{
  home.packages = [
    calendarEvents
    calendarApp
    pkgs.gnome-online-accounts-gtk
  ];
}
