import QtQuick
import QtQuick.Controls.Basic as Controls
import qs.services

SettingRow {
    id: row
    property alias text: field.text
    property alias placeholder: field.placeholderText
    property int entryWidth: 250
    signal accepted(string value)
    Controls.TextField {
        id: field
        width: row.entryWidth
        implicitHeight: Math.max(36, contentHeight + 14)
        color: Theme.colors.text
        placeholderTextColor: Theme.colors.textDim
        font.family: Theme.font
        font.pointSize: Theme.textNormal
        leftPadding: 12
        rightPadding: 12
        selectByMouse: true
        Accessible.name: row.title
        onAccepted: row.accepted(text)
        background: Rectangle {
            radius: 9
            color: "#303037"
            border.width: field.activeFocus ? 2 : 1
            border.color: field.activeFocus ? "#5b9bff" : "#1affffff"
        }
    }
}
