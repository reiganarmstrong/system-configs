{ pkgs }:
pkgs.runCommand "desktop-media-tests"
  {
    nativeBuildInputs = [ pkgs.qt6.qtdeclarative ];
    LC_ALL = "C.UTF-8";
    QT_QPA_PLATFORM = "offscreen";
    QT_QUICK_BACKEND = "software";
    FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
  }
  ''
    mkdir tests
    cp ${./tst_timeline.qml} tests/tst_timeline.qml
    cp ${../../modules/home/quickshell/qml/components/MediaTimeline.qml} tests/MediaTimeline.qml
    export QML_IMPORT_PATH=${pkgs.qt6.qtdeclarative}/lib/qt-6/qml
    export HOME="$TMPDIR"
    qmltestrunner -input tests/tst_timeline.qml -o -,txt
    touch $out
  ''
