// A centred icon and message for an empty list.
import QtQuick
import qs.services

Item {
    property string icon
    property string text

    width: parent ? parent.width : 0
    implicitHeight: column.implicitHeight + 40

    Column {
        id: column
        anchors.centerIn: parent
        spacing: 6
        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: parent.parent.icon
            size: 22
            color: Theme.colors.textDim
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: parent.parent.text
            dim: true
            size: Theme.textSmall
        }
    }
}
