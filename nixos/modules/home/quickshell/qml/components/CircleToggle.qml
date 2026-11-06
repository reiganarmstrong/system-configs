// A round glass button the height of one grid cell. White when on.
import QtQuick
import qs.services

GlassTile {
    id: circle

    property string icon
    property bool active: false
    signal clicked

    radius: width / 2
    solid: active
    hovered: area.containsMouse

    Icon {
        anchors.centerIn: parent
        name: circle.icon
        size: circle.width * 0.32
        color: circle.active ? Theme.colors.accentText : Theme.colors.text
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: circle.clicked()
    }
}
