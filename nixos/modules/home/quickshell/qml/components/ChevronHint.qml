// A chevron that fades in over the existing pill, with no extra surface.
import QtQuick
import qs.services

Item {
    id: hint
    property bool hovered: false
    property bool revealOnHover: true
    implicitWidth: 26
    implicitHeight: 34

    Icon {
        anchors.centerIn: parent
        name: "chevron-right"
        size: 11
        color: hint.hovered ? Theme.colors.text : Theme.colors.textDim
        opacity: !hint.revealOnHover || hint.hovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.ms(120) } }
    }
}
