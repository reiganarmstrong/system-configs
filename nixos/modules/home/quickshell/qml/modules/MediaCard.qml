// Now playing: cover art, title and artist, progress, and transport buttons.
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

Rectangle {
    readonly property var player: Media.player

    implicitHeight: 76

    // MPRIS does not stream the position; refresh it while playing.
    Timer {
        interval: 1000
        repeat: true
        running: player?.isPlaying ?? false
        onTriggered: player.positionChanged()
    }
    radius: Theme.radius.tile
    color: Theme.tileFill

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 56
            Layout.preferredHeight: 56
            radius: 10
            color: Theme.tileFill
            clip: true

            Image {
                anchors.fill: parent
                source: player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        Column {
            Layout.fillWidth: true
            spacing: 2

            Label {
                width: parent.width
                text: player?.trackTitle || "Nothing playing"
                weight: Font.DemiBold
            }
            Label {
                width: parent.width
                text: player?.trackArtist ?? ""
                dim: true
                size: Theme.textSmall
            }
            Rectangle {
                width: parent.width
                height: 3
                radius: 2
                color: Theme.tileFill
                Rectangle {
                    width: player?.lengthSupported && player.length > 0
                        ? parent.width * Math.min(1, player.position / player.length) : 0
                    height: parent.height
                    radius: 2
                    color: Theme.colors.text
                }
            }
        }

        Icon {
            name: "skip-back"
            MouseArea { anchors.fill: parent; onClicked: player?.previous() }
        }
        RoundButton {
            icon: player?.isPlaying ? "pause" : "play"
            diameter: 34
            active: true
            onClicked: player?.togglePlaying()
        }
        Icon {
            name: "skip-forward"
            MouseArea { anchors.fill: parent; onClicked: player?.next() }
        }
    }
}
