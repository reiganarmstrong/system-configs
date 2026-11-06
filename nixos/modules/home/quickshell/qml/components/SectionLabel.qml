// A small dim heading above a group of rows, with an optional spinner.
import QtQuick
import qs.services

Item {
    id: section
    property string text
    property bool busy: false

    width: parent ? parent.width : 0
    implicitHeight: 24

    Label {
        id: label
        x: 10
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        text: section.text
        dim: true
        size: Theme.textSmall * 0.9
        weight: Font.DemiBold
    }
    Spinner {
        anchors.left: label.right
        anchors.leftMargin: 6
        anchors.verticalCenter: label.verticalCenter
        size: 10
        visible: section.busy
    }
}
