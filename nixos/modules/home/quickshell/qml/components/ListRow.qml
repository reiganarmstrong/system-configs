// One row in a sub-panel list: a round badge, title and status line, and a
// trailing slot. The badge turns white when the item is current, like the
// control centre's pills. Rows can expand to show inline content below.
import QtQuick
import Quickshell
import qs.services

Item {
    id: row

    property string icon
    property string iconSource: ""
    property string title
    property string subtitle: ""
    property bool selected: false
    property bool busy: false
    property bool error: false
    property bool interactive: true
    property bool expanded: false
    default property alias trailing: trailingRow.data
    property alias expansion: expander.data
    signal clicked
    signal rightClicked

    readonly property real rowHeight: subtitle !== "" ? 42 : 36

    width: parent ? parent.width : 297
    implicitHeight: rowHeight + (expanded ? expander.implicitHeight + 8 : 0)
    clip: true
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: interactive

    Behavior on implicitHeight { NumberAnimation { duration: Motion.ms(180); easing.type: Easing.OutCubic } }

    Rectangle {
        id: background
        width: parent.width
        height: row.rowHeight
        radius: 10
        color: !row.interactive ? "transparent"
            : area.pressed ? Theme.withAlpha("#ffffff", 0.14)
            : area.containsMouse ? Theme.withAlpha("#ffffff", 0.08) : "transparent"
        border.width: row.activeFocus ? 1 : 0
        border.color: Theme.colors.highlight
        Behavior on color { ColorAnimation { duration: Motion.ms(100) } }
    }

    Rectangle {
        id: badge
        x: 6
        y: (row.rowHeight - height) / 2
        width: 26
        height: 26
        radius: 13
        visible: row.icon !== "" || row.iconSource !== ""
        color: row.iconSource !== "" && image.status === Image.Ready ? "transparent"
            : row.selected ? Theme.colors.accent : Theme.withAlpha("#ffffff", 0.14)
        Behavior on color { ColorAnimation { duration: Motion.ms(150) } }

        Image {
            id: image
            anchors.centerIn: parent
            width: 22
            height: 22
            source: row.iconSource
            sourceSize: Qt.size(44, 44)
            visible: status === Image.Ready
        }
        Icon {
            anchors.centerIn: parent
            name: row.icon
            size: 13
            visible: !image.visible
            color: row.selected ? Theme.colors.accentText : Theme.colors.text
        }
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: badge.visible ? 40 : 10
        anchors.right: trailingRow.left
        anchors.rightMargin: 8
        y: (row.rowHeight - height) / 2

        Label {
            width: parent.width
            text: row.title
            size: Theme.textSmall
            weight: Font.Medium
            dim: !row.interactive && row.icon === ""
        }
        Label {
            width: parent.width
            text: row.subtitle
            visible: text !== ""
            size: Theme.textSmall * 0.9
            dim: !row.error
            color: row.error ? Theme.colors.urgent : Theme.colors.textDim
        }
    }

    Row {
        id: trailingRow
        anchors.right: parent.right
        anchors.rightMargin: 10
        y: (row.rowHeight - height) / 2
        spacing: 6

        Spinner {
            visible: row.busy
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: area
        width: parent.width
        height: row.rowHeight
        enabled: row.interactive
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => mouse.button === Qt.RightButton ? row.rightClicked() : row.clicked()
    }

    Column {
        id: expander
        x: 40
        y: row.rowHeight + 4
        width: parent.width - 50
        visible: row.expanded
        opacity: row.expanded ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.ms(180) } }
    }

    Keys.onReturnPressed: if (interactive) row.clicked()
    Keys.onSpacePressed: if (interactive) row.clicked()
}
