// A wide capsule toggle: a round badge, then a title and status line. The
// badge turns white with a dark icon when the toggle is on. An `openable`
// pill works like macOS: the badge toggles and the rest opens details.
import QtQuick
import qs.services

GlassTile {
    id: pill

    property string icon
    property string title
    property string subtitle
    property bool active: false
    property bool openable: false
    signal clicked
    signal toggled
    signal opened

    radius: height / 2
    hovered: area.containsMouse

    Rectangle {
        id: badge
        anchors.left: parent.left
        anchors.leftMargin: (pill.height - height) / 2
        anchors.verticalCenter: parent.verticalCenter
        width: pill.height * 0.58
        height: width
        radius: width / 2
        color: pill.active ? (badgeArea.containsMouse ? Qt.darker(Theme.colors.accent, 1.06) : Theme.colors.accent)
            : Theme.withAlpha("#ffffff", badgeArea.containsMouse ? 0.22 : 0.14)
        scale: badgeArea.pressed ? 0.92 : 1
        Behavior on color { ColorAnimation { duration: Motion.ms(150) } }
        Behavior on scale { NumberAnimation { duration: Motion.ms(80) } }

        Icon {
            anchors.centerIn: parent
            name: pill.icon
            size: parent.width * 0.46
            color: pill.active ? Theme.colors.accentText : Theme.colors.text
        }
    }

    Column {
        anchors.left: badge.right
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: pill.openable ? 40 : 10
        anchors.verticalCenter: parent.verticalCenter

        Label {
            width: parent.width
            text: pill.title
            weight: Font.Bold
            size: Theme.textSmall
        }
        Label {
            width: parent.width
            text: pill.subtitle
            dim: true
            size: Theme.textSmall * 0.9
            visible: text !== ""
        }
    }

    ChevronHint {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        visible: pill.openable
        hovered: area.containsMouse && !badgeArea.containsMouse
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.openable ? pill.opened() : pill.clicked()
    }
    // The badge toggles on its own when the pill opens details.
    MouseArea {
        id: badgeArea
        anchors.fill: badge
        anchors.margins: -4
        enabled: pill.openable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.toggled()
    }
}
