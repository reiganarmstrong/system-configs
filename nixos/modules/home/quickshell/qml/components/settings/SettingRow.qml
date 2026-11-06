import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

Rectangle {
    id: row
    property string title
    property string detail
    default property alias controls: slot.data
    width: parent.width
    implicitHeight: Math.max(58, labels.implicitHeight + 24, slot.childrenRect.height + 20)
    height: implicitHeight
    radius: 10
    color: Theme.withAlpha("#ffffff", 0.04)
    border.width: 1
    border.color: Theme.withAlpha("#ffffff", 0.055)
    opacity: enabled ? 1 : 0.45
    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 18
        ColumnLayout {
            id: labels
            Layout.fillWidth: true
            spacing: 4
            Label { text: row.title; Layout.fillWidth: true; weight: Font.DemiBold; wrapMode: Text.Wrap; elide: Text.ElideNone }
            Label {
                text: row.detail
                visible: text !== ""
                dim: true
                size: Theme.textSmall
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                elide: Text.ElideNone
            }
        }
        Item {
            id: slot
            Layout.preferredWidth: childrenRect.width
            Layout.preferredHeight: childrenRect.height
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
