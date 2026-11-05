// A small frosted capsule for the bar.
import QtQuick
import qs.services

Glass {
    default property alias content: row.data
    property real padding: 12

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: 28
    radius: height / 2

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
    }
}
