// Select a day to see its synchronized events, or open it in Calendar.
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
        Label {
            text: "Today"
            size: Theme.textSmall
            dim: true
            MouseArea {
                cursorShape: Qt.PointingHandCursor
                anchors.fill: parent
                anchors.margins: -5
                onClicked: {
                    calendar.shown = new Date(calendar.today);
                    CalendarData.selected = new Date(calendar.today);
                }
            }
        }
        Item {
            implicitWidth: 30
            implicitHeight: 30
            Icon { anchors.centerIn: parent; name: "chevron-left" }
            MouseArea {
                cursorShape: Qt.PointingHandCursor
                anchors.fill: parent
                onClicked: calendar.shown = new Date(calendar.shown.getFullYear(), calendar.shown.getMonth() - 1, 1)
            }
        }
        Item {
            implicitWidth: 30
            implicitHeight: 30
            Icon { anchors.centerIn: parent; name: "chevron-right" }
            MouseArea {
                cursorShape: Qt.PointingHandCursor
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
                readonly property bool selected: day.toDateString() === CalendarData.selected.toDateString()

                Layout.fillWidth: true
                implicitHeight: 32
                radius: 16
                color: selected ? Theme.colors.accent : "transparent"
                border.width: isToday && !selected ? 1 : 0
                border.color: Theme.colors.accent

                Label {
                    anchors.centerIn: parent
                    text: parent.day.getDate()
                    color: parent.selected ? Theme.colors.accentText
                        : parent.inMonth ? Theme.colors.text : Theme.withAlpha(Theme.colors.text, 0.3)
                    weight: parent.isToday ? Font.Bold : Font.Medium
                }
                MouseArea {
                cursorShape: Qt.PointingHandCursor
                    anchors.fill: parent
                    onClicked: {
                        CalendarData.selected = new Date(parent.day);
                        if (!parent.inMonth)
                            calendar.shown = new Date(parent.day);
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Label {
            Layout.fillWidth: true
            text: Qt.formatDate(CalendarData.selected, "ddd d MMM")
            weight: Font.Bold
            size: Theme.textSmall
        }
        Label {
            text: "Open Calendar"
            dim: true
            size: Theme.textSmall
            MouseArea { cursorShape: Qt.PointingHandCursor; anchors.fill: parent; anchors.margins: -4; onClicked: CalendarData.openCalendar() }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 5

        Repeater {
            model: CalendarData.events.slice(0, 4)
            Item {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 24
                RowLayout {
                    anchors.fill: parent
                    spacing: 8
                    Label {
                        text: parent.parent.modelData.allDay ? "All day" : parent.parent.modelData.time
                        size: Theme.textSmall
                        dim: true
                        Layout.preferredWidth: 45
                    }
                    Label {
                        Layout.fillWidth: true
                        text: parent.parent.modelData.title
                        size: Theme.textSmall
                        elide: Text.ElideRight
                    }
                }
                MouseArea { cursorShape: Qt.PointingHandCursor; anchors.fill: parent; onClicked: CalendarData.openCalendar() }
            }
        }

        Label {
            Layout.fillWidth: true
            visible: CalendarData.error !== "" || CalendarData.loading || CalendarData.events.length === 0
            text: CalendarData.error || (CalendarData.loading ? "Loading calendars…" : "No events for this day")
            size: Theme.textSmall
            dim: true
            wrapMode: Text.WordWrap
        }
        Label {
            visible: CalendarData.events.length > 4
            text: "+" + (CalendarData.events.length - 4) + " more in Calendar"
            size: Theme.textSmall
            dim: true
            MouseArea { cursorShape: Qt.PointingHandCursor; anchors.fill: parent; onClicked: CalendarData.openCalendar() }
        }
        Label {
            text: "Connect calendars…"
            size: Theme.textSmall
            dim: true
            MouseArea { cursorShape: Qt.PointingHandCursor; anchors.fill: parent; anchors.margins: -4; onClicked: CalendarData.openAccounts() }
        }
    }
}
