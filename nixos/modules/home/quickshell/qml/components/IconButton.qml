// A round, borderless icon button: back chevrons, session and transport icons.
import QtQuick
import qs.services

Item {
    id: button
    property string icon
    property real size: 26
    property real iconSize: 13
    // For on/off controls such as shuffle: full white when active, dim when not.
    property bool toggle: false
    property bool active: false
    signal clicked

    implicitWidth: size
    implicitHeight: size
    opacity: enabled ? 1 : 0.35

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: area.pressed ? Theme.withAlpha("#ffffff", 0.22)
            : area.containsMouse ? Theme.withAlpha("#ffffff", 0.14) : "transparent"
        Behavior on color { ColorAnimation { duration: Motion.ms(100) } }
    }
    Icon {
        anchors.centerIn: parent
        name: button.icon
        size: button.iconSize
        color: !button.toggle || button.active ? Theme.colors.text : Theme.colors.textDim
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
