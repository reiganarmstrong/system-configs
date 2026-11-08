// One notification: app icon or image, summary, body and actions.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import Quickshell
import qs.components
import qs.services

Glass {
    id: card

    property var notification
    // Inside the notification centre, cards sit on a panel already.
    property bool nested: false
    signal dismissed

    implicitHeight: layout.implicitHeight + 24
    radius: Theme.radius.tile + 2
    fillOpacity: nested ? 0 : Prefs.get("panelOpacity", Theme.opacity.panel)
    color: nested ? Theme.tileFill : Theme.panelFill
    border.width: nested ? 0 : 1

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Image {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            Layout.alignment: Qt.AlignTop
            source: card.notification?.image || Quickshell.iconPath(card.notification?.appIcon ?? "", true)
            fillMode: Image.PreserveAspectFit
            visible: status === Image.Ready
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                Layout.rightMargin: 28
                Label {
                    Layout.fillWidth: true
                    text: card.notification?.summary ?? ""
                    weight: Font.Bold
                }
                Label {
                    Layout.maximumWidth: Math.min(90, card.width / 3)
                    text: card.notification?.appName ?? ""
                    dim: true
                    size: Theme.textSmall
                }
            }
            Label {
                Layout.fillWidth: true
                text: card.notification?.body ?? ""
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: 4
                dim: true
                visible: text !== ""
            }
            Row {
                spacing: 6
                visible: (card.notification?.actions ?? []).length > 0
                Repeater {
                    model: card.notification?.actions ?? []
                    Rectangle {
                        required property var modelData
                        width: actionLabel.implicitWidth + 20
                        height: 26
                        radius: 13
                        color: Theme.tileFillHover
                        Label {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: parent.modelData.text
                            size: Theme.textSmall
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: parent.modelData.invoke()
                        }
                    }
                }
            }
        }
    }

    // Click to dismiss from the popup stack; the close button removes it
    // from history too.
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: card.dismissed()
    }
    Controls.ToolButton {
        id: dismissButton
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        width: 28
        height: 28
        Accessible.name: "Dismiss notification"
        contentItem: Icon { name: "x"; size: 13; color: Theme.colors.textDim }
        background: Rectangle {
            radius: 7
            color: dismissButton.hovered ? Theme.hoverFill : "transparent"
            border.width: dismissButton.activeFocus ? 1 : 0
            border.color: Theme.focusRing
        }
        onClicked: {
            card.dismissed();
            card.notification?.dismiss();
        }
    }
}
