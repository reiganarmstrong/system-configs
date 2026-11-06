pragma Singleton
// EDS supplies the same synchronized calendars that GNOME Calendar uses.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property date selected: new Date()
    readonly property string dayKey: Qt.formatDate(selected, "yyyy-MM-dd")
    property var events: []
    property string error: ""
    readonly property bool loading: reader.running

    onDayKeyChanged: {
        events = [];
        error = "";
        refresh.start();
    }

    function openCalendar() {
        ShellState.close();
        // GNOME Calendar's EDS parser expects the current locale's date format.
        const date = Qt.formatDate(selected, Qt.locale(), Locale.ShortFormat);
        Quickshell.execDetached(["gnome-calendar", "--date", date]);
    }

    function openAccounts() {
        ShellState.close();
        Quickshell.execDetached(["gnome-online-accounts-gtk"]);
    }

    Timer {
        id: refresh
        interval: 50
        onTriggered: {
            if (!reader.running && ShellState.openPanel === "dash") {
                reader.requestedDay = root.dayKey;
                root.error = "";
                reader.command = ["desktop-calendar-events", root.dayKey];
                reader.running = true;
            }
        }
    }

    Timer {
        interval: 60000
        running: ShellState.openPanel === "dash"
        repeat: true
        triggeredOnStart: true
        onTriggered: refresh.start()
    }

    Process {
        id: reader
        property string requestedDay
        stdout: StdioCollector {
            onStreamFinished: {
                if (reader.requestedDay !== root.dayKey)
                    return;
                try {
                    const result = JSON.parse(text);
                    root.events = result.events ?? [];
                    root.error = result.error ?? (result.unavailable?.length > 0
                        ? "Some calendars are unavailable. Check Online Accounts." : "");
                } catch (_) {
                    root.error = "Calendar service unavailable";
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (requestedDay !== root.dayKey)
                refresh.start();
            else if (exitCode !== 0)
                root.error = "Calendar service unavailable";
        }
    }
}
