// An inline password entry with a show/hide eye and a Join button.
import QtQuick
import qs.services

Item {
    id: field

    property alias text: input.text
    property string placeholder: "Password"
    property bool busy: false
    property string error: ""
    // WPA passphrases are at least eight characters.
    property int minimumLength: 8
    signal accepted(string text)
    signal cancelled

    readonly property bool ready: input.text.length >= minimumLength && !busy

    width: parent ? parent.width : 247
    implicitHeight: 28 + (error !== "" ? 18 : 0)

    function focusField() {
        input.forceActiveFocus();
    }
    function submit() {
        if (ready)
            accepted(input.text);
    }

    Rectangle {
        id: box
        anchors.left: parent.left
        anchors.right: join.left
        anchors.rightMargin: 6
        height: 28
        radius: 8
        color: Theme.withAlpha("#000000", 0.25)
        border.width: 1
        border.color: field.error !== "" ? Theme.colors.urgent
            : input.activeFocus ? Theme.colors.highlight : Theme.withAlpha("#ffffff", 0.14)

        TextInput {
            id: input
            anchors.left: parent.left
            anchors.right: eye.left
            anchors.leftMargin: 8
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            echoMode: TextInput.Password
            passwordCharacter: "•"
            color: Theme.colors.text
            selectionColor: Theme.colors.highlight
            font.family: Theme.font
            font.pointSize: Theme.textSmall
            clip: true
            enabled: !field.busy
            onAccepted: field.submit()
            Keys.onEscapePressed: field.cancelled()

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: field.placeholder
                dim: true
                size: Theme.textSmall
                visible: input.text === ""
            }
        }
        Icon {
            id: eye
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            name: input.echoMode === TextInput.Password ? "eye" : "eye-off"
            size: 12
            color: Theme.colors.textDim
            MouseArea {
                anchors.fill: parent
                anchors.margins: -5
                cursorShape: Qt.PointingHandCursor
                onClicked: input.echoMode = input.echoMode === TextInput.Password ? TextInput.Normal : TextInput.Password
            }
        }
    }

    Rectangle {
        id: join
        anchors.right: parent.right
        width: Math.max(46, joinLabel.implicitWidth + 20)
        height: 28
        radius: 8
        color: joinArea.containsMouse && field.ready ? Qt.darker(Theme.colors.accent, 1.08) : Theme.colors.accent
        opacity: field.ready || field.busy ? 1 : 0.4

        Label {
            id: joinLabel
            anchors.centerIn: parent
            text: "Join"
            visible: !field.busy
            size: Theme.textSmall
            weight: Font.Bold
            color: Theme.colors.accentText
        }
        Spinner {
            anchors.centerIn: parent
            size: 12
            visible: field.busy
            color: Theme.colors.accentText
        }
        MouseArea {
            id: joinArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: field.submit()
        }
    }

    Label {
        y: 32
        text: field.error
        visible: field.error !== ""
        size: Theme.textSmall * 0.85
        color: Theme.colors.urgent
    }
}
