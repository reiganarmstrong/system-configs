// A control-centre toggle: a round icon badge with a title and status line.
// The badge turns white when the toggle is on.
import QtQuick
import qs.services

Rectangle {
    id: tile

    property string icon
    property string title
    property string subtitle
    property bool active: false
    property bool flat: false
    signal clicked

    implicitHeight: 52
    radius: Theme.radius.tile
    color: flat ? "transparent" : area.containsMouse ? Theme.tileFillHover : Theme.tileFill

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Rectangle {
            width: 34
            height: 34
            radius: 17
            color: tile.active ? Theme.colors.accent : Theme.withAlpha("#ffffff", 0.12)

            Icon {
                anchors.centerIn: parent
                name: tile.icon
                size: 17
                color: tile.active ? Theme.colors.accentText : Theme.colors.text
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: tile.width - 70

            Label {
                width: parent.width
                text: tile.title
                weight: Font.DemiBold
            }
            Label {
                width: parent.width
                text: tile.subtitle
                dim: true
                size: Theme.textSmall
                visible: text !== ""
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: tile.clicked()
    }
}
