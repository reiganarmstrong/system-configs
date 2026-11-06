// Sound, like macOS: output and input levels, every output and input device
// to choose from, and a volume for each app that's playing.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.components
import qs.services

SubPanel {
    id: page

    title: "Sound"
    footerText: "Sound Settings…"
    onFooterClicked: ShellState.openSettings("sound")

    // Keep volumes, names and properties live while the page is open.
    PwObjectTracker {
        objects: [...Audio.outputs, ...Audio.inputs, ...Audio.streams]
    }

    SectionLabel { text: "Output" }
    Item {
        width: parent.width
        height: 32
        ThinSlider {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            accessibleName: "Output volume"
            startIcon: Audio.icon
            wheelEnabled: false
            value: Audio.muted ? 0 : Audio.volume
            onMoved: v => Audio.setVolume(v)
            onStartIconClicked: Audio.toggleMute()
        }
    }
    Repeater {
        model: Audio.outputs
        ListRow {
            required property var modelData
            icon: Audio.deviceIcon(modelData)
            title: Audio.deviceName(modelData)
            selected: modelData === Audio.sink
            onClicked: Audio.selectOutput(modelData)
        }
    }

    SectionLabel { text: "Input" }
    Item {
        width: parent.width
        height: 32
        ThinSlider {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            accessibleName: "Input level"
            startIcon: Audio.micMuted ? "mic-off" : "mic"
            wheelEnabled: false
            value: Audio.micMuted ? 0 : Audio.micVolume
            onMoved: v => Audio.setMicVolume(v)
            onStartIconClicked: Audio.toggleMic()
        }
    }
    Repeater {
        model: Audio.inputs
        ListRow {
            required property var modelData
            icon: Audio.deviceIcon(modelData)
            title: Audio.deviceName(modelData)
            selected: modelData === Audio.source
            onClicked: Audio.selectInput(modelData)
        }
    }

    SectionLabel {
        text: "Applications"
        visible: Audio.streams.length > 0
    }
    Repeater {
        model: Audio.streams
        AppVolumeRow {}
    }
}
