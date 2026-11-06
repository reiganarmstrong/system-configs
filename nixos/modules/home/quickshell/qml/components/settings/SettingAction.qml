import QtQuick
SettingRow {
    id: row
    property string buttonText: "Open…"
    signal activated()
    SettingButton { text: row.buttonText; onClicked: row.activated() }
}
