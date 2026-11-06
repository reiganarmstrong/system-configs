import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.modules.cc
import qs.components
import qs.components.settings
import qs.services

Column {
    required property var host
    spacing: 10
    PwObjectTracker {
        objects: [...Audio.outputs, ...Audio.inputs, ...Audio.streams]
    }
    SettingChoice {
        title: "Output device"
        choiceWidth: 280
        options: Audio.outputs.map(n => n.description || n.name)
        values: Audio.outputs.map(n => n.id)
        value: Audio.sink?.id
        enabled: Audio.outputs.length > 0
        onChosen: v => Audio.selectOutput(Audio.outputs.find(n => n.id === v))
    }
    SettingLevel {
        title: "Output volume"
        value: Audio.volume
        enabled: Audio.sink !== null
        onMoved: v => Audio.setVolume(v)
    }
    SettingToggle {
        title: "Mute output"
        checked: Audio.muted
        enabled: Audio.sink !== null
        onToggled: v => Audio.toggleMute()
    }
    SettingChoice {
        title: "Input device"
        choiceWidth: 280
        options: Audio.inputs.map(n => n.description || n.name)
        values: Audio.inputs.map(n => n.id)
        value: Audio.source?.id
        enabled: Audio.inputs.length > 0
        onChosen: v => Audio.selectInput(Audio.inputs.find(n => n.id === v))
    }
    SettingLevel {
        title: "Microphone level"
        value: Audio.micVolume
        enabled: Audio.source !== null
        onMoved: v => Audio.setMicVolume(v)
    }
    SettingToggle {
        title: "Mute microphone"
        checked: Audio.micMuted
        enabled: Audio.source !== null
        onToggled: v => Audio.toggleMic()
    }
    SectionLabel {
        text: "Application volumes"
    }
    Repeater {
        model: Audio.streams
        AppVolumeRow {}
    }
    SettingRow {
        visible: Audio.streams.length === 0
        title: "No apps are playing audio"
        detail: "An app appears here while it has an audio stream."
    }
    SettingAction {
        title: "Advanced device profiles"
        detail: "Channel balance, hardware profiles and individual stream routing in the audio mixer."
        buttonText: "Open mixer…"
        onActivated: host.launch(["pavucontrol"])
    }
}
