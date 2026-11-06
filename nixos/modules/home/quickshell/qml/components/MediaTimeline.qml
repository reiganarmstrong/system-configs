// Keep finite-track timing through incomplete MPRIS updates. Firefox/Zen can
// drop duration and position after a playing SetPosition (Mozilla 2065930),
// so their playing seeks wait for Pause before SetPosition and then resume.
import QtQuick

QtObject {
    id: timeline
    property var player: null
    readonly property var track: player?.uniqueId ?? null
    readonly property real reportedDuration: player?.lengthSupported && Number.isFinite(player.length) && player.length > 0 ? player.length : 0
    property real rememberedDuration: 0
    readonly property real duration: reportedDuration || rememberedDuration
    readonly property real position: pendingPlayer === player ? pendingPosition : (player?.position ?? 0)
    readonly property bool seekable: (player?.canSeek ?? false) && (player?.positionSupported ?? false) && duration > 0
    readonly property bool browserPlayer: (player?.dbusName ?? "").startsWith("org.mpris.MediaPlayer2.firefox.")

    onPlayerChanged: resetDuration()
    onTrackChanged: resetDuration()
    onReportedDurationChanged: rememberDuration()
    function rememberDuration(): void {
        if (reportedDuration > 0) rememberedDuration = reportedDuration;
    }
    function resetDuration(): void {
        rememberedDuration = 0;
        // Track changes arrive before the rest of the new metadata.
        Qt.callLater(rememberDuration);
    }

    property var pendingPlayer: null
    property var pendingTrack: null
    property real pendingPosition: 0
    readonly property bool pendingPlaying: pendingPlayer?.isPlaying ?? false
    onPendingPlayingChanged: Qt.callLater(finishSeek)

    function seek(fraction: real): void {
        if (!seekable || !Number.isFinite(fraction)) return;
        const target = Math.max(0, Math.min(1, fraction)) * duration;
        if (pendingPlayer === player) {
            pendingPosition = target;
            return;
        }
        if (browserPlayer && player.isPlaying && player.canPause && player.canPlay) {
            // Set target and track before publishing pendingPlayer, since the
            // observed pause acknowledgement may arrive synchronously.
            pendingPosition = target;
            pendingTrack = track;
            pendingPlayer = player;
            pauseTimeout.restart();
            player.pause();
            finishSeek();
        } else {
            player.position = target;
        }
    }
    function finishSeek(): void {
        if (!pendingPlayer || pendingPlayer.isPlaying) return;
        const targetPlayer = pendingPlayer;
        const targetTrack = pendingTrack;
        const targetPosition = pendingPosition;
        pendingPlayer = null;
        pauseTimeout.stop();
        // A delayed pause must never seek a different track.
        if (targetPlayer.uniqueId === targetTrack && targetPlayer.canSeek && targetPlayer.positionSupported)
            targetPlayer.position = targetPosition;
        targetPlayer.play();
    }
    function cancelSeek(): void {
        const targetPlayer = pendingPlayer;
        pendingPlayer = null;
        pauseTimeout.stop();
        // Restore the playback state that existed before our pause request.
        if (targetPlayer) targetPlayer.play();
    }
    readonly property Timer pauseTimeout: Timer {
        interval: 1500
        onTriggered: timeline.cancelSeek()
    }
    Component.onDestruction: cancelSeek()
}
