{ pkgs }:
pkgs.runCommand "desktop-dropdown-tests"
  {
    nativeBuildInputs = [ pkgs.qt6.qtdeclarative ];
    QT_QPA_PLATFORM = "offscreen";
    QT_QUICK_BACKEND = "software";
    FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
  }
  ''
    cp -r ${./.} tests
    chmod -R u+w tests
    cp ${../../modules/home/quickshell/qml/components/settings/ChoiceBox.qml} tests/ChoiceBox.qml
    cp ${../../modules/home/quickshell/qml/components/Icon.qml} tests/qs/components/Icon.qml
    export QML_IMPORT_PATH=${pkgs.qt6.qtdeclarative}/lib/qt-6/qml
    qmltestrunner -import "$PWD/tests" -input tests/tst_choicebox.qml -o -,txt
    touch $out
  ''
