// A separate top-bar popup for searching and recalling copied text or images.
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.components.settings
import qs.services

Popup {
    id: root
    surfaceRadius: 24
    name: "clipboard"
    placement: "top-right"
    keyboard: true
    readonly property ClipboardSelection historySelection: ClipboardSelection {
        id: selection
        items: root.results
        active: root.open
    }
    property alias selectedId: selection.selectedId
    property bool confirmClear: false
    readonly property var results: Clipboard.items.filter(item => item.preview.toLowerCase().includes(search.text.trim().toLowerCase()))
    readonly property int selectedIndex: selection.selectedIndex

    function selectFirst() { selection.reset(); }
    function moveSelection(delta: int) { selection.move(delta); }
    function copySelected() { if (selectedId && !confirmClear) Clipboard.copy(selectedId); }
    onOpenChanged: if (open) {
        search.text = "";
        confirmClear = false;
        selectFirst();
        Clipboard.refresh();
        search.forceActiveFocus();
    }
    Connections {
        target: Clipboard
        function onCopied() { if (root.open) ShellState.close(); }
    }

    Glass {
        width: 480
        height: layout.implicitHeight + 32
        radius: 24
        ColumnLayout {
            id: layout
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Label { text: "Clipboard history"; weight: Font.Bold; Layout.fillWidth: true }
                SettingButton {
                    text: Clipboard.paused ? "Resume" : "Pause"
                    enabled: Clipboard.ready && !Clipboard.mutating
                    onClicked: Clipboard.pause(!Clipboard.paused)
                    Accessible.name: Clipboard.paused ? "Resume clipboard capture" : "Pause clipboard capture"
                }
                SettingButton {
                    text: "Clear…"
                    enabled: Clipboard.items.length > 0 && !Clipboard.mutating
                    onClicked: root.confirmClear = !root.confirmClear
                }
            }
            RowLayout {
                Layout.fillWidth: true
                visible: root.confirmClear
                Label { text: "Clear all history?"; Layout.fillWidth: true; size: Theme.textSmall }
                SettingButton { text: "Cancel"; onClicked: root.confirmClear = false }
                SettingButton { text: "Clear"; destructive: true; onClicked: { root.confirmClear = false; Clipboard.clear(); } }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 38
                radius: 12
                color: Theme.tileFill
                Icon { id: glyph; anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 16; color: Theme.colors.textDim }
                TextInput {
                    id: search
                    anchors.left: glyph.right
                    anchors.right: parent.right
                    anchors.leftMargin: 10
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.colors.text
                    font.family: Theme.font
                    font.pointSize: Theme.textNormal
                    selectionColor: Theme.withAlpha("#ffffff", 0.3)
                    Accessible.name: "Search clipboard history"
                    onTextChanged: root.selectFirst()
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down) root.moveSelection(1);
                        else if (event.key === Qt.Key_Up) root.moveSelection(-1);
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.copySelected();
                        else return;
                        event.accepted = true;
                    }
                    Label { text: "Search history"; dim: true; visible: search.text === "" }
                }
            }
            Label {
                Layout.fillWidth: true
                visible: Clipboard.error !== ""
                text: Clipboard.error
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                color: Theme.colors.urgent
                size: Theme.textSmall
            }
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.preferredHeight: root.results.length ? Math.min(contentHeight, Math.max(120, Math.min(392, root.height - 250))) : 82
                clip: true
                spacing: 4
                model: root.results
                currentIndex: root.selectedIndex
                boundsBehavior: Flickable.StopAtBounds
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    width: list.width
                    height: 52
                    radius: 12
                    color: modelData.id === root.selectedId ? Theme.selectFill : copyArea.containsMouse ? Theme.hoverFill : "transparent"
                    MouseArea {
                        id: copyArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.selectedId = row.modelData.id; root.copySelected(); }
                    }
                    Rectangle {
                        x: 9
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        height: 36
                        radius: 8
                        color: Theme.tileFill
                        clip: true
                        Icon { anchors.centerIn: parent; name: row.modelData.kind === "image" ? "image" : "type"; size: 17; visible: preview.status !== Image.Ready }
                        Image {
                            id: preview
                            anchors.fill: parent
                            source: row.modelData.thumbnail
                            sourceSize: Qt.size(96, 72)
                            asynchronous: true
                            fillMode: Image.PreserveAspectFit
                        }
                    }
                    Label {
                        anchors.left: parent.left
                        anchors.right: removeButton.left
                        anchors.leftMargin: 56
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.preview
                        textFormat: Text.PlainText
                        size: Theme.textSmall
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                    }
                    IconButton {
                        id: removeButton
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "x"
                        iconSize: 13
                        visible: copyArea.containsMouse || row.modelData.id === root.selectedId
                        enabled: !Clipboard.mutating
                        onClicked: Clipboard.remove(row.modelData.id)
                        Accessible.role: Accessible.Button
                        Accessible.name: "Delete clipboard item"
                    }
                }
                Label {
                    anchors.centerIn: parent
                    width: parent.width - 24
                    horizontalAlignment: Text.AlignHCenter
                    text: !Clipboard.ready && Clipboard.busy ? "Loading history…" : search.text ? "No matches" : Clipboard.paused ? "Capture is paused" : "Copied text and images will appear here"
                    visible: list.count === 0 && Clipboard.error === ""
                    dim: true
                    size: Theme.textSmall
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Label { text: "Enter copies · Ctrl+D deletes"; dim: true; size: Theme.textSmall * 0.9; Layout.fillWidth: true }
                Label { text: Clipboard.paused ? "Capture paused" : Clipboard.items.length + " items"; dim: true; size: Theme.textSmall * 0.9 }
            }
        }
    }
    Shortcut {
        sequence: "Ctrl+D"
        enabled: root.open && root.selectedId !== "" && !Clipboard.mutating
        onActivated: Clipboard.remove(root.selectedId)
    }
}
