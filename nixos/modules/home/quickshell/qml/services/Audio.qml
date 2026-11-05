pragma Singleton
// The default speaker and microphone from PipeWire.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? true
    readonly property bool micMuted: source?.audio?.muted ?? true
    readonly property string sinkName: sink?.description ?? ""

    readonly property string icon: muted || volume === 0 ? "volume-x" : volume < 0.5 ? "volume-1" : "volume-2"

    function setVolume(v: real) {
        if (sink?.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(1, v));
        }
    }
    function toggleMute() {
        if (sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }
    function toggleMic() {
        if (source?.audio)
            source.audio.muted = !source.audio.muted;
    }

    // Volume and mute only update for nodes that something tracks.
    PwObjectTracker {
        objects: [root.sink, root.source]
    }
}
