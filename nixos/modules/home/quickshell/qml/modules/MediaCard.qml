// A centered compact player with padding around artwork, text and controls.
// Clicking the card outside the transport controls opens the full player.
import QtQuick
import qs.components
import qs.services

GlassTile {
    id: card
    readonly property var player: Media.player
    signal opened
    radius: 22
    hovered: openArea.containsMouse

    MouseArea {
        id: openArea
        anchors.fill: parent
        z: -1
        enabled: card.player !== null
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.opened()
    }
    Timer {
        interval: 1000
        repeat: true
        running: card.player?.isPlaying ?? false
        onTriggered: card.player.positionChanged()
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - 36
        spacing: 8
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 32
            height: 32
            radius: 8
            color: Theme.withAlpha("#ffffff", 0.12)
            clip: true
            Icon {
                anchors.centerIn: parent
                name: "music"
                size: 16
                color: Theme.colors.textDim
                visible: cover.status !== Image.Ready
            }
            Image {
                id: cover
                anchors.fill: parent
                source: card.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }
        Column {
            width: parent.width
            spacing: 2
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: card.player?.trackTitle || "Not Playing"
                textFormat: Text.PlainText
                weight: Font.Bold
                size: Theme.textSmall
            }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: card.player?.trackArtist ?? ""
                textFormat: Text.PlainText
                dim: true
                size: Theme.textSmall * 0.9
                visible: text !== ""
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            IconButton {
                size: 28
                icon: "skip-back"
                iconSize: 16
                enabled: card.player !== null
                onClicked: card.player?.previous()
                Accessible.role: Accessible.Button
                Accessible.name: "Previous track"
                Accessible.onPressAction: card.player?.previous()
            }
            IconButton {
                size: 28
                icon: card.player?.isPlaying ? "pause" : "play"
                iconSize: 19
                enabled: card.player !== null
                onClicked: card.player?.togglePlaying()
                Accessible.role: Accessible.Button
                Accessible.name: "Play or pause"
                Accessible.onPressAction: card.player?.togglePlaying()
            }
            IconButton {
                size: 28
                icon: "skip-forward"
                iconSize: 16
                enabled: card.player !== null
                onClicked: card.player?.next()
                Accessible.role: Accessible.Button
                Accessible.name: "Next track"
                Accessible.onPressAction: card.player?.next()
            }
        }
    }
}
