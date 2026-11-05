// A circular icon button, with an optional caption underneath.
import QtQuick
import qs.services

Item {
    id: button

    property string icon
    property string caption
    property bool active: false
    property real diameter: 40
    signal clicked

    implicitWidth: Math.max(diameter, captionLabel.implicitWidth)
    implicitHeight: diameter + (caption !== "" ? captionLabel.implicitHeight + 6 : 0)

    Rectangle {
        id: circle
        anchors.horizontalCenter: parent.horizontalCenter
        width: button.diameter
        height: button.diameter
        radius: width / 2
        color: button.active ? Theme.colors.accent : area.containsMouse ? Theme.tileFillHover : Theme.tileFill

        Icon {
            anchors.centerIn: parent
            name: button.icon
            size: button.diameter * 0.42
            color: button.active ? Theme.colors.accentText : Theme.colors.text
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: button.clicked()
        }
    }

    Label {
        id: captionLabel
        anchors.top: circle.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        text: button.caption
        dim: true
        size: Theme.textSmall
        visible: text !== ""
    }
}
