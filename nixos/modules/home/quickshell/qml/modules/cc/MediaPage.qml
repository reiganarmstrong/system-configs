// Now Playing, expanded: large artwork, track details, a scrubber with
// elapsed and remaining time, transport controls, and a player picker when
// more than one app is playing.
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Mpris
import qs.components
import qs.services

SubPanel {
    id: page

    readonly property var player: Media.player
    readonly property MediaTimeline timeline: MediaTimeline { player: page.player }
    readonly property bool seekable: timeline.seekable
    readonly property real length: timeline.duration
    // While dragging, the times follow the drag rather than playback.
    readonly property real shownPosition: scrubber.pressed ? scrubber.shownValue * length : timeline.position
    property bool pickerOpen: false

    title: "Now Playing"
    scrolls: false

    signal finished

    function handleEscape(): bool {
        if (pickerOpen) {
            pickerOpen = false;
            return true;
        }
        return false;
    }

    // Close the page when the last player goes away.
    onPlayerChanged: if (!player) finished()

    // MPRIS doesn't stream the position; poll it while playing.
    Timer {
        interval: 500
        repeat: true
        running: page.player?.isPlaying ?? false
        onTriggered: page.player.positionChanged()
    }

    headerTrailing: [
        Label {
            visible: Media.players.length <= 1
            anchors.verticalCenter: parent.verticalCenter
            text: page.player?.identity ?? ""
            dim: true
            size: Theme.textSmall * 0.9
        },
        Rectangle {
            id: pickerButton
            visible: Media.players.length > 1
            anchors.verticalCenter: parent.verticalCenter
            width: pickerRow.implicitWidth + 16
            height: 24
            radius: 12
            color: Theme.withAlpha("#ffffff", pickerArea.containsMouse ? 0.16 : 0.1)
            Row {
                id: pickerRow
                anchors.centerIn: parent
                spacing: 4
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: page.player?.identity ?? ""
                    size: Theme.textSmall * 0.9
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "chevrons-up-down"
                    size: 11
                }
            }
            MouseArea {
                id: pickerArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: page.pickerOpen = !page.pickerOpen
            }
        }
    ]

    Item {
        width: parent.width
        readonly property real contentPadding: 18
        height: content.implicitHeight + contentPadding * 2

        Column {
            id: content
            x: parent.contentPadding
            y: parent.contentPadding
            width: parent.width - parent.contentPadding * 2

            // Artwork; clicking it brings the player's window forward.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 200
                height: 200
                radius: 14
                color: Theme.withAlpha("#ffffff", 0.1)
                clip: true

                Icon {
                    anchors.centerIn: parent
                    name: "music"
                    size: 44
                    color: Theme.colors.textDim
                    visible: art.status !== Image.Ready
                }
                Image {
                    id: art
                    anchors.fill: parent
                    source: page.player?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(400, 400)
                    asynchronous: true
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: page.player?.canRaise ?? false
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        page.player.raise();
                        ShellState.close();
                    }
                }
            }

            Item { width: 1; height: 14 }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: page.player?.trackTitle || "Not Playing"
                weight: Font.Bold
            }
            Item { width: 1; height: 2 }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: page.player?.trackArtist ?? ""
                visible: text !== ""
                size: Theme.textSmall
                opacity: 0.8
            }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: page.player?.trackAlbum ?? ""
                visible: text !== ""
                dim: true
                size: Theme.textSmall * 0.9
            }
            Item { width: 1; height: 12 }

            Scrubber {
                id: scrubber
                width: parent.width
                seekable: page.seekable
                value: page.length > 0 ? page.timeline.position / page.length : 0
                onCommitted: v => page.timeline.seek(v)
            }
            Item {
                width: parent.width
                height: 16
                Label {
                    anchors.left: parent.left
                    text: Media.formatTime(page.shownPosition)
                    dim: true
                    size: Theme.textSmall * 0.85
                }
                Label {
                    anchors.right: parent.right
                    text: page.length > 0 ? "−" + Media.formatTime(page.length - page.shownPosition) : "Live"
                    visible: page.player !== null
                    dim: true
                    size: Theme.textSmall * 0.85
                }
            }
            Item { width: 1; height: 8 }

            // Shuffle, previous, play/pause, next, repeat.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 18

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 32
                    iconSize: 14
                    icon: "shuffle"
                    toggle: true
                    active: page.player?.shuffle ?? false
                    opacity: page.player?.shuffleSupported ? 1 : 0
                    enabled: page.player?.shuffleSupported ?? false
                    onClicked: page.player.shuffle = !page.player.shuffle
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 36
                    iconSize: 20
                    icon: "skip-back"
                    enabled: page.player?.canGoPrevious ?? false
                    onClicked: page.player.previous()
                }
                Rectangle {
                    width: 48
                    height: 48
                    radius: 24
                    color: playArea.containsMouse ? "#eeeeee" : "#ffffff"
                    scale: playArea.pressed ? 0.94 : 1
                    Behavior on scale { NumberAnimation { duration: Motion.ms(80) } }
                    // Lucide's play and pause on its 24-unit grid, filled, with
                    // the same 2-unit round-joined stroke as the outline icons
                    // so the corners match. CurveRenderer antialiases the edges.
                    Item {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        scale: 22 / 24
                        Shape {
                            anchors.fill: parent
                            visible: !(page.player?.isPlaying ?? false)
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: "#000000"
                                strokeColor: "#000000"
                                strokeWidth: 2
                                joinStyle: ShapePath.RoundJoin
                                capStyle: ShapePath.RoundCap
                                PathSvg { path: "M5 5a2 2 0 0 1 3.008-1.728l11.997 6.998a2 2 0 0 1 .003 3.458l-12 7A2 2 0 0 1 5 19z" }
                            }
                        }
                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            visible: page.player?.isPlaying ?? false
                            Rectangle { width: 6; height: 19; radius: 2; color: "#000000"; antialiasing: true }
                            Rectangle { width: 6; height: 19; radius: 2; color: "#000000"; antialiasing: true }
                        }
                    }
                    MouseArea {
                        id: playArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.player?.togglePlaying()
                    }
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 36
                    iconSize: 20
                    icon: "skip-forward"
                    enabled: page.player?.canGoNext ?? false
                    onClicked: page.player.next()
                }
                IconButton {
                    readonly property int loop: page.player?.loopState ?? MprisLoopState.None
                    anchors.verticalCenter: parent.verticalCenter
                    size: 32
                    iconSize: 14
                    icon: loop === MprisLoopState.Track ? "repeat-1" : "repeat"
                    toggle: true
                    active: loop !== MprisLoopState.None
                    opacity: page.player?.loopSupported ? 1 : 0
                    enabled: page.player?.loopSupported ?? false
                    onClicked: page.player.loopState = loop === MprisLoopState.None ? MprisLoopState.Playlist
                        : loop === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
                }
            }
        }

        // The player picker, floating under its button.
        Glass {
            visible: page.pickerOpen
            anchors.right: parent.right
            y: 0
            z: 10
            width: 170
            height: pickerList.implicitHeight + 8
            radius: 12
            fillOpacity: 0.92

            Column {
                id: pickerList
                x: 4
                y: 4
                width: parent.width - 8
                Repeater {
                    model: Media.players
                    Rectangle {
                        required property var modelData
                        width: pickerList.width
                        height: 30
                        radius: 8
                        color: modelData === page.player ? Theme.withAlpha("#ffffff", 0.12)
                            : rowArea.containsMouse ? Theme.withAlpha("#ffffff", 0.08) : "transparent"
                        Icon {
                            x: 8
                            anchors.verticalCenter: parent.verticalCenter
                            name: parent.modelData.isPlaying ? "play" : "music"
                            size: 12
                        }
                        Label {
                            x: 28
                            width: parent.width - 36
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData.identity
                            size: Theme.textSmall * 0.9
                        }
                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                Media.choose(parent.modelData);
                                page.pickerOpen = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
