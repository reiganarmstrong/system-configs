// An on/off switch for sub-panel headers.
import QtQuick
import qs.services

Item {
    id: sw
    property bool checked: false
    signal toggled(bool on)

    implicitWidth: 32
    implicitHeight: 18
    activeFocusOnTab: true
    opacity: enabled ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: sw.checked ? Theme.colors.highlight : Theme.withAlpha("#ffffff", 0.22)
        border.width: sw.activeFocus ? 1 : 0
        border.color: Theme.colors.highlight
        Behavior on color { ColorAnimation { duration: Motion.ms(140) } }

        Rectangle {
            width: 14
            height: 14
            radius: 7
            y: 2
            x: sw.checked ? parent.width - width - 2 : 2
            color: "white"
            border.width: 1
            border.color: "#40000000"
            Behavior on x { NumberAnimation { duration: Motion.ms(140); easing.type: Easing.OutCubic } }
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled(!sw.checked)
    }
    Keys.onSpacePressed: sw.toggled(!sw.checked)
}
