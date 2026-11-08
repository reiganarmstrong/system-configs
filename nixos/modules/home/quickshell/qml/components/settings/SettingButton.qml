import QtQuick
import QtQuick.Controls.Basic as Controls
import qs.services

Controls.Button {
    id: control
    property bool primary: false
    property bool destructive: false
    implicitWidth: Math.max(80, contentItem.implicitWidth + 24)
    implicitHeight: 32
    hoverEnabled: true
    activeFocusOnTab: true
    Accessible.name: text
    font.family: Theme.font
    font.pointSize: Theme.textSmall
    contentItem: Text {
        text: control.text
        font: control.font
        color: control.destructive ? Theme.colors.urgent : "white"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: 8
        color: control.primary ? Theme.colors.highlight : Theme.withAlpha("#ffffff", control.hovered ? 0.14 : 0.08)
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? Theme.focusRing : Theme.withAlpha("#ffffff", 0.08)
        opacity: control.enabled ? 1 : 0.4
    }
}
