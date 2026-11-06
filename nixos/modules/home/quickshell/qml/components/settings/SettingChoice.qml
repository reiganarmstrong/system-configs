import QtQuick

SettingRow {
    id: row
    property var options: []
    property var values: options
    property var value
    property int choiceWidth: 200
    signal chosen(var value)

    ChoiceBox {
        width: row.choiceWidth
        options: row.options
        currentIndex: row.values.findIndex(v => v === row.value)
        Accessible.name: row.title
        Accessible.description: row.detail
        onActivated: index => row.chosen(row.values[index])
    }
}
