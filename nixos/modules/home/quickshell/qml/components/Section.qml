// A rounded group inside a panel, optionally titled.
import QtQuick
import qs.services

Rectangle {
    id: section

    default property alias content: column.data
    property string title
    property string detail

    implicitHeight: column.implicitHeight + 24
    radius: Theme.radius.tile
    color: Theme.tileFill

    Column {
        id: column
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Item {
            width: parent.width
            height: titleLabel.implicitHeight
            visible: section.title !== ""

            Label {
                id: titleLabel
                text: section.title
                weight: Font.Bold
            }
            Label {
                anchors.right: parent.right
                width: Math.min(implicitWidth, parent.width - titleLabel.implicitWidth - 12)
                horizontalAlignment: Text.AlignRight
                text: section.detail
                dim: true
                size: Theme.textSmall
            }
        }
    }
}
