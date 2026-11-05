// The app launcher: type to filter installed applications, Enter to open.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.services

Popup {
    id: launcher
    name: "launcher"
    placement: "center"
    keyboard: true

    readonly property var apps: DesktopEntries.applications.values
        .filter(a => !a.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))
    readonly property var results: {
        const q = search.text.trim().toLowerCase();
        if (q === "")
            return apps;
        const score = a => {
            const name = a.name.toLowerCase();
            if (name.startsWith(q)) return 0;
            if (name.includes(q)) return 1;
            if ((a.genericName ?? "").toLowerCase().includes(q)) return 2;
            if (a.keywords.some(k => k.toLowerCase().includes(q))) return 3;
            return -1;
        };
        return apps.map(a => [score(a), a]).filter(p => p[0] >= 0)
            .sort((x, y) => x[0] - y[0]).map(p => p[1]);
    }
    property int selected: 0

    onOpenChanged: {
        if (open) {
            search.text = "";
            selected = 0;
            search.forceActiveFocus();
        }
    }

    function launch(app: var) {
        if (!app)
            return;
        ShellState.close();
        app.execute();
    }

    Glass {
        width: 560
        height: layout.implicitHeight + Theme.spacing.panel * 2
        radius: Theme.radius.panel + 4

        ColumnLayout {
            id: layout
            anchors.fill: parent
            anchors.margins: Theme.spacing.panel
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 44
                radius: 22
                color: Theme.tileFill

                Icon {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    color: Theme.colors.textDim
                }
                TextInput {
                    id: search
                    anchors.left: searchIcon.right
                    anchors.right: parent.right
                    anchors.leftMargin: 12
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.colors.text
                    font.family: Theme.font
                    font.pointSize: Theme.textLarge
                    selectionColor: Theme.withAlpha("#ffffff", 0.3)
                    onTextChanged: launcher.selected = 0

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down) {
                            launcher.selected = Math.min(launcher.selected + 1, launcher.results.length - 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            launcher.selected = Math.max(launcher.selected - 1, 0);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            launcher.launch(launcher.results[launcher.selected]);
                            event.accepted = true;
                        }
                    }

                    Label {
                        text: "Search apps"
                        dim: true
                        size: Theme.textLarge
                        visible: search.text === ""
                    }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 7 * 48)
                clip: true
                model: launcher.results
                currentIndex: launcher.selected
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    width: list.width
                    height: 46
                    radius: 12
                    color: index === launcher.selected ? Theme.tileFillHover : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Image {
                            width: 30
                            height: 30
                            anchors.verticalCenter: parent.verticalCenter
                            source: Quickshell.iconPath(row.modelData.icon, "application-x-executable")
                            sourceSize: Qt.size(60, 60)
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Label { text: row.modelData.name; weight: Font.DemiBold }
                            Label {
                                text: row.modelData.comment || row.modelData.genericName
                                dim: true
                                size: Theme.textSmall
                                visible: text !== ""
                                width: list.width - 80
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: launcher.selected = row.index
                        onClicked: launcher.launch(row.modelData)
                    }
                }
            }
        }
    }
}
