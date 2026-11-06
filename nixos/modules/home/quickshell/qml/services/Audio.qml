pragma Singleton
// The default speaker and microphone from PipeWire.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var outputs: Pipewire.nodes.values.filter(n => n.audio && !n.isStream && n.isSink)
    readonly property var inputs: Pipewire.nodes.values.filter(n => n.audio && !n.isStream && !n.isSink && !n.name.endsWith(".monitor"))
    // Apps playing sound, each with its own volume.
    readonly property var streams: Pipewire.nodes.values.filter(n => n.audio && n.isStream && n.isSink)

    function deviceName(node: var): string {
        return node?.description || node?.nickname || node?.name || "";
    }
    // A Lucide glyph for a speaker, headphones, display or microphone.
    function deviceIcon(node: var): string {
        const p = node?.properties ?? {};
        const form = p["device.form-factor"] ?? "";
        const name = (node?.name ?? "").toLowerCase();
        if (p["device.bus"] === "bluetooth")
            return form === "headset" || form === "hands-free" ? "headset" : "headphones";
        if (form === "headphone" || name.includes("headphone"))
            return "headphones";
        if (form === "headset")
            return "headset";
        if (name.includes("hdmi") || name.includes("displayport"))
            return "monitor-speaker";
        if (node?.isSink)
            return "speaker";
        return form === "webcam" ? "camera" : "mic";
    }
    readonly property real micVolume: source?.audio?.volume ?? 0
    function selectOutput(node: var) { Pipewire.preferredDefaultAudioSink = node; }
    function selectInput(node: var) { Pipewire.preferredDefaultAudioSource = node; }
    function setMicVolume(v: real) { if (source?.audio) source.audio.volume = Math.max(0, Math.min(1, v)); }
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
