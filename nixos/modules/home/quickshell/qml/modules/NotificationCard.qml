// One notification: app icon or image, summary, body and actions.
import QtQuick
import QtQuick.Layouts
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
    fillOpacity: nested ? 0 : Theme.opacity.panel
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
                Label {
                    Layout.fillWidth: true
                    text: card.notification?.summary ?? ""
                    weight: Font.Bold
                }
                Label {
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
    Icon {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        name: "x"
        size: 13
        color: Theme.colors.textDim
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            onClicked: {
                card.dismissed();
                card.notification?.dismiss();
            }
        }
    }
}
