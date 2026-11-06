pragma Singleton
// The media player to show: the one playing, else the most recent.
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root
    readonly property var players: Mpris.players.values
    // A player picked in Now Playing; otherwise the one playing, else the first.
    property var chosen: null
    readonly property var player: (chosen && players.includes(chosen)) ? chosen
        : players.find(p => p.isPlaying) ?? players[0] ?? null
    function choose(p: var) {
        chosen = p;
    }
    function formatTime(seconds: real): string {
        const s = Math.max(0, Math.floor(seconds));
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = s % 60;
        const pad = n => (n < 10 ? "0" : "") + n;
        return h > 0 ? h + ":" + pad(m) + ":" + pad(sec) : m + ":" + pad(sec);
    }
}
