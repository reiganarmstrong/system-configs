// A month grid with today highlighted; arrows change the month.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.services

ColumnLayout {
    id: calendar

    property date shown: new Date()
    readonly property date today: clock.date
    spacing: 8

    SystemClock {
        id: clock
        precision: SystemClock.Hours
    }

    RowLayout {
        Layout.fillWidth: true
        Label {
            Layout.fillWidth: true
            text: Qt.formatDate(calendar.shown, "MMMM yyyy")
            weight: Font.Bold
            size: Theme.textLarge
        }
        Icon {
            name: "chevron-left"
            MouseArea {
                anchors.fill: parent
                onClicked: calendar.shown = new Date(calendar.shown.getFullYear(), calendar.shown.getMonth() - 1, 1)
            }
        }
        Icon {
            name: "chevron-right"
            MouseArea {
                anchors.fill: parent
                onClicked: calendar.shown = new Date(calendar.shown.getFullYear(), calendar.shown.getMonth() + 1, 1)
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 7
        rowSpacing: 2
        columnSpacing: 2

        Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            Label {
                required property string modelData
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                dim: true
                size: Theme.textSmall
            }
        }

        Repeater {
            // Six weeks starting on the Monday on or before the 1st.
            model: 42
            Rectangle {
                required property int index
                readonly property date first: new Date(calendar.shown.getFullYear(), calendar.shown.getMonth(), 1)
                readonly property date day: new Date(first.getFullYear(), first.getMonth(),
                    1 - ((first.getDay() + 6) % 7) + index)
                readonly property bool inMonth: day.getMonth() === calendar.shown.getMonth()
                readonly property bool isToday: day.toDateString() === calendar.today.toDateString()

                Layout.fillWidth: true
                implicitHeight: 32
                radius: 16
                color: isToday ? Theme.colors.accent : "transparent"

                Label {
                    anchors.centerIn: parent
                    text: parent.day.getDate()
                    color: parent.isToday ? Theme.colors.accentText
                        : parent.inMonth ? Theme.colors.text : Theme.withAlpha(Theme.colors.text, 0.3)
                    weight: parent.isToday ? Font.Bold : Font.Medium
                }
            }
        }
    }
}
