// A control-centre page: header with a title and optional
// switch; a scrolling body; and an optional "… Settings" footer link.
import QtQuick
import qs.services

Item {
    id: panel

    property string title
    property bool showSwitch: false
    property alias checked: toggle.checked
    property alias switchEnabled: toggle.enabled
    property alias headerTrailing: trailing.data
    property string footerText: ""
    property real maxHeight: 560
    property bool scrolls: true
    default property alias content: body.data
    signal back
    signal switchToggled(bool on)
    signal footerClicked

    readonly property real contentInset: 10
    readonly property real chromeHeight: header.height + 13 + (footer.visible ? footer.height + 7 : 0)

    width: parent ? parent.width : 297
    implicitHeight: chromeHeight + view.height

    Item {
        id: header
        width: parent.width
        height: 32

        Label {
            anchors.left: parent.left
            anchors.leftMargin: panel.contentInset
            anchors.right: trailing.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            // The font's ascent leaves the letters a pixel high of the switch.
            anchors.verticalCenterOffset: 1
            text: panel.title
            weight: Font.Bold
        }
        Row {
            id: trailing
            anchors.right: parent.right
            anchors.rightMargin: panel.contentInset
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Switch {
                id: toggle
                visible: panel.showSwitch
                anchors.verticalCenter: parent.verticalCenter
                onToggled: on => panel.switchToggled(on)
            }
        }
    }

    Separator {
        id: topRule
        x: panel.contentInset
        width: parent.width - panel.contentInset * 2
        y: header.height + 8
    }

    Flickable {
        id: view
        y: topRule.y + 5
        width: parent.width
        height: panel.scrolls ? Math.min(contentHeight, Math.max(80, panel.maxHeight - panel.chromeHeight)) : contentHeight
        contentHeight: body.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        clip: true

        // The body leaves a gutter for the scrollbar so it never covers a row.
        Column {
            id: body
            width: view.width - (view.interactive ? 10 : 0)
            spacing: 2
        }

        Rectangle {
            visible: view.interactive
            x: view.width - 3
            y: view.visibleArea.yPosition * view.height
            width: 3
            height: view.visibleArea.heightRatio * view.height
            radius: 1.5
            color: Theme.withAlpha("#ffffff", 0.28)
        }
    }

    Column {
        id: footer
        anchors.top: view.bottom
        anchors.topMargin: 6
        width: parent.width
        visible: panel.footerText !== ""
        spacing: 6

        Separator {
            x: panel.contentInset
            width: parent.width - panel.contentInset * 2
        }
        Rectangle {
            width: parent.width
            height: 32
            radius: 10
            color: footerArea.containsMouse ? Theme.hoverFill : "transparent"
            Label {
                x: panel.contentInset
                anchors.verticalCenter: parent.verticalCenter
                text: panel.footerText
                size: Theme.textSmall
                weight: Font.Medium
            }
            MouseArea {
                id: footerArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: panel.footerClicked()
            }
        }
    }

    // The mouse's back button goes back too.
    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.BackButton
        onClicked: panel.back()
    }
}
