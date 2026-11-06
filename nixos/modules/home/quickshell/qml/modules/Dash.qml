// The notification centre, opened from the clock: a month calendar and the
// notification history.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.services

Popup {
    name: "dash"
    placement: "top"

    Glass {
        width: 380
        height: layout.implicitHeight + Theme.spacing.panel * 2

        ColumnLayout {
            id: layout
            anchors.fill: parent
            anchors.margins: Theme.spacing.panel
            spacing: Theme.spacing.tile

            Calendar {
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                Label {
                    Layout.fillWidth: true
                    text: "Notifications"
                    weight: Font.Bold
                }
                Label {
                    text: "Clear"
                    dim: true
                    size: Theme.textSmall
                    visible: Notifs.history.length > 0
                    MouseArea { anchors.fill: parent; onClicked: Notifs.clearAll() }
                }
            }

            Label {
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                horizontalAlignment: Text.AlignHCenter
                text: "No notifications"
                dim: true
                visible: Notifs.history.length === 0
            }

            Flickable {
                Layout.fillWidth: true
                // Leave room for the selected day's agenda on the laptop display.
                Layout.preferredHeight: Math.min(contentHeight, 220)
                contentHeight: list.implicitHeight
                clip: true
                visible: Notifs.history.length > 0

                Column {
                    id: list
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: [...Notifs.history].reverse()
                        NotificationCard {
                            required property var modelData
                            width: list.width
                            nested: true
                            notification: modelData
                            onDismissed: modelData.dismiss()
                        }
                    }
                }
            }
        }
    }
}
