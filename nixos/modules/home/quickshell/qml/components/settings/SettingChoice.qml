import QtQuick

SettingRow {
    id: row
    property var options: []
    property var values: options
    property var value
    property int choiceWidth: 200
    signal chosen(var value)

    ChoiceBox {
        id: choice
        readonly property int ownerIndex: row.values.findIndex(v => v === row.value)
        width: row.choiceWidth
        options: row.options
        currentIndex: ownerIndex
        // ComboBox resets currentIndex itself when its model changes (for
        // example a search that hides the stored value), which drops the binding.
        onModelChanged: currentIndex = Qt.binding(() => choice.ownerIndex)
        Accessible.name: row.title
        Accessible.description: row.detail
        onActivated: index => {
            row.chosen(row.values[index]);
            // Selecting sets currentIndex internally without re-reading the
            // owner. Re-bind so a rejected or failed choice is not left shown.
            currentIndex = Qt.binding(() => choice.ownerIndex);
        }
    }
}
