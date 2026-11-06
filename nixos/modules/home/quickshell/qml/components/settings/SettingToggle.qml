import QtQuick
import QtQuick.Controls.Basic as Controls
import qs.services

SettingRow {
    id: row
    property bool checked: false
    signal toggled(bool value)
    Controls.Switch {
        id: control
        // Show only the owner's state. A checkable switch flips itself on
        // click and stays flipped when a change fails or changes nothing.
        checkable: false
        checked: row.checked
        implicitWidth: 42
        implicitHeight: 28
        padding: 0
        hoverEnabled: true
        activeFocusOnTab: true
        Accessible.name: row.title
        Accessible.description: row.detail
        onClicked: row.toggled(!row.checked)
        indicator: Rectangle {
            x: 2
            y: 3
            width: 38
            height: 22
            radius: 11
            color: control.checked ? Theme.colors.highlight : Theme.withAlpha("#ffffff", 0.18)
            border.width: control.activeFocus ? 2 : 0
            border.color: "#5b9bff"
            Rectangle {
                x: control.checked ? 18 : 2
                y: 2
                width: 18
                height: 18
                radius: 9
                color: "white"
            }
        }
    }
}
