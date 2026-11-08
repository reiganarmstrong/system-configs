{ pkgs }:
pkgs.runCommand "desktop-brightness-tests"
  {
    nativeBuildInputs = [ pkgs.qt6.qtdeclarative ];
    LC_ALL = "C.UTF-8";
    QT_QPA_PLATFORM = "offscreen";
  }
  ''
    mkdir tests
    cp ${./tst_ddc.qml} tests/tst_ddc.qml
    cp ${../../modules/home/quickshell/qml/services/ddc.js} tests/ddc.js
    export QML_IMPORT_PATH=${pkgs.qt6.qtdeclarative}/lib/qt-6/qml
    export HOME="$TMPDIR"
    qmltestrunner -input tests/tst_ddc.qml -o -,txt
    touch $out
  ''
