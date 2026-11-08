// A control-centre page: header with a title and optional switch; a
// scrolling body; and an optional "… Settings" footer link.
//
// One column on a shared grid. Rows, the footer and their hover fills span
// the panel's width; their text, the title, the switch and the rules sit
// Theme.spacing.inset inside it, so every text edge lines up.
import QtQuick
import QtQuick.Layouts
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

    readonly property real inset: Theme.spacing.inset
    // Everything but the body, which gets whatever height is left.
    readonly property real chromeHeight: top.implicitHeight + (bottom.visible ? bottom.implicitHeight : 0)

    width: parent ? parent.width : 297
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout
        width: parent.width
        spacing: 0

        ColumnLayout {
            id: top
            Layout.fillWidth: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                Layout.leftMargin: panel.inset
                Layout.rightMargin: panel.inset
                spacing: 8

                HeaderLabel {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: panel.title
                }
                Row {
                    id: trailing
                    Layout.alignment: Qt.AlignVCenter
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
                Layout.fillWidth: true
                Layout.leftMargin: panel.inset
                Layout.rightMargin: panel.inset
                Layout.topMargin: 8
                Layout.bottomMargin: 5
            }
        }

        Flickable {
            id: view
            Layout.fillWidth: true
            Layout.preferredHeight: panel.scrolls
                ? Math.min(contentHeight, Math.max(80, panel.maxHeight - panel.chromeHeight))
                : contentHeight
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
                x: view.width - width
                y: view.visibleArea.yPosition * view.height
                width: 3
                height: view.visibleArea.heightRatio * view.height
                radius: 1.5
                color: Theme.withAlpha("#ffffff", 0.28)
            }
        }

        ColumnLayout {
            id: bottom
            Layout.fillWidth: true
            visible: panel.footerText !== ""
            spacing: 0

            Separator {
                Layout.fillWidth: true
                Layout.leftMargin: panel.inset
                Layout.rightMargin: panel.inset
                Layout.topMargin: 6
                Layout.bottomMargin: 6
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: 10
                color: footerArea.containsMouse ? Theme.hoverFill : "transparent"

                Label {
                    anchors.fill: parent
                    leftPadding: panel.inset
                    rightPadding: panel.inset
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
    }

    // The mouse's back button goes back too.
    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.BackButton
        onClicked: panel.back()
    }
}
