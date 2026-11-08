// One app's playback volume: its icon (click to mute), name and what it's
// playing, and a slider.
import QtQuick
import Quickshell
import qs.components
import qs.services

Item {
    id: row

    required property var modelData
    readonly property var node: modelData
    readonly property var props: node?.properties ?? {}
    readonly property bool muted: node?.audio?.muted ?? false
    readonly property string appName: props["application.name"] || node?.description || node?.name || "App"
    readonly property string media: props["media.name"] ?? ""

    width: parent ? parent.width : 297
    height: 52

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: hover.hovered ? Theme.hoverFill : "transparent"
        Behavior on color { ColorAnimation { duration: Motion.ms(100) } }
    }
    HoverHandler { id: hover }

    Item {
        id: appIcon
        x: 8
        y: 4
        width: 20
        height: 20
        opacity: row.muted ? 0.4 : 1

        Image {
            id: image
            anchors.fill: parent
            sourceSize: Qt.size(40, 40)
            source: Quickshell.iconPath(row.props["application.icon-name"] || row.props["application.process.binary"] || "", true)
            visible: status === Image.Ready
        }
        Rectangle {
            anchors.fill: parent
            radius: 10
            visible: !image.visible
            color: Theme.withAlpha("#ffffff", 0.14)
            Icon {
                anchors.centerIn: parent
                name: "app-window"
                size: 11
            }
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: if (row.node?.audio) row.node.audio.muted = !row.node.audio.muted
        }
    }

    Label {
        x: 36
        y: 4
        width: parent.width - 46
        height: 20
        textFormat: Text.StyledText
        // Rich text so the track name can be dimmer; escape what apps send.
        function esc(t) { return t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }
        text: esc(row.appName) + (row.media !== "" ? "<font color=\"" + Theme.colors.textDim + "\"> — " + esc(row.media) + "</font>" : "")
        size: Theme.textSmall
        weight: Font.Medium
    }

    ThinSlider {
        x: 30
        y: 26
        width: parent.width - 40
        height: 24
        accessibleName: row.appName + " volume"
        wheelEnabled: false
        value: row.muted ? 0 : (row.node?.audio?.volume ?? 0)
        onMoved: v => {
            if (row.node?.audio) {
                row.node.audio.muted = false;
                row.node.audio.volume = v;
            }
        }
    }
}
