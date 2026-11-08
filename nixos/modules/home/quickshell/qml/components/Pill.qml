// A flat item on the solid bar: no fill of its own, a soft grey rounded
// highlight under the pointer when it can be clicked.
import QtQuick
import qs.services

Item {
    id: pill
    default property alias content: row.data
    property real padding: 8
    property alias spacing: row.spacing
    property bool clickable: false
    // Menus suppress bar hover feedback without disabling their buttons.
    readonly property bool hovered: clickable && area.containsMouse && ShellState.openPanel === ""
    signal clicked

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: 26

    Rectangle {
        anchors.fill: parent
        radius: 7
        color: ShellState.openPanel !== "" ? "transparent"
            : area.pressed ? Theme.pressFill : pill.hovered ? Theme.hoverFill : "transparent"
        Behavior on color {
            enabled: ShellState.openPanel === ""
            ColorAnimation { duration: Motion.ms(120) }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: pill.clickable
        hoverEnabled: true
        cursorShape: pill.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: pill.clicked()
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
    }
}
