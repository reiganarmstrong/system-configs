// A wide capsule slider whose white fill shows the level, with an icon at
// the start and the percentage at the end.
import QtQuick
import qs.services

Rectangle {
    id: slider

    property string icon
    property real value: 0
    signal moved(real value)

    implicitHeight: 30
    radius: height / 2
    color: Theme.tileFill
    clip: true

    Rectangle {
        width: Math.max(slider.height, slider.width * slider.value)
        height: parent.height
        radius: height / 2
        color: Theme.colors.accent
    }

    Icon {
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        name: slider.icon
        size: 15
        color: Theme.colors.accentText
    }

    Label {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(slider.value * 100) + "%"
        size: Theme.textSmall
        color: slider.value > 0.9 ? Theme.colors.accentText : Theme.colors.textDim
    }

    MouseArea {
        anchors.fill: parent
        function update(mouse) {
            slider.moved(Math.max(0, Math.min(1, mouse.x / width)));
        }
        onPressed: mouse => update(mouse)
        onPositionChanged: mouse => update(mouse)
    }
}
