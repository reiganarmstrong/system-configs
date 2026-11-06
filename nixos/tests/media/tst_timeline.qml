import QtQuick
import QtTest

Item {
    width: 400
    height: 100
    QtObject {
        id: browser
        property string dbusName: "org.mpris.MediaPlayer2.firefox.test"
        property int uniqueId: 1
        property bool canSeek: true
        property bool positionSupported: true
        property bool lengthSupported: true
        property real length: 180
        property real position: 10
        property bool isPlaying: true
        property bool canPause: true
        property bool canPlay: true
        property int playingSeeks: 0
        property int pausedSeeks: 0
        property bool acknowledgePause: true
        property int pauseCalls: 0
        property int playCalls: 0
        property bool emulateBrokenSeek: true
        // Replay Mozilla bug 2065930: a playing seek drops duration;
        // pausing refreshes valid timing. No website or personal player is used.
        onPositionChanged: {
            if (isPlaying) {
                playingSeeks++;
                if (emulateBrokenSeek) { lengthSupported = false; length = 0; }
            } else pausedSeeks++;
        }
        onIsPlayingChanged: if (!isPlaying) { length = 180; lengthSupported = true; }
        function pause() { pauseCalls++; if (acknowledgePause) pauseAck.restart(); }
        function play() { playCalls++; isPlaying = true; }
        property Timer pauseAck: Timer { interval: 25; onTriggered: browser.isPlaying = false }
    }
    MediaTimeline { id: timeline; player: browser }
    TestCase {
        name: "MediaTimeline"
        when: windowShown
        function init() {
            timeline.cancelSeek();
            browser.pauseAck.stop();
            timeline.player = null;
            browser.emulateBrokenSeek = false;
            browser.isPlaying = false;
            browser.dbusName = "org.mpris.MediaPlayer2.firefox.test";
            browser.uniqueId = 1;
            browser.canSeek = true;
            browser.positionSupported = true;
            browser.lengthSupported = true;
            browser.length = 180;
            browser.position = 10;
            browser.acknowledgePause = true;
            browser.canPause = true;
            browser.canPlay = true;
            browser.playingSeeks = 0;
            browser.pausedSeeks = 0;
            browser.pauseCalls = 0;
            browser.playCalls = 0;
            browser.emulateBrokenSeek = true;
            browser.isPlaying = true;
            timeline.player = browser;
            wait(1);
        }
        function cleanup() { timeline.cancelSeek(); browser.pauseAck.stop(); }
        function test_playing_browser_seek_keeps_finite_timeline() {
            verify(timeline.seekable);
            timeline.seek(0.5);
            wait(80);
            verify(timeline.seekable, "Playing seek became Live and disabled the timeline");
            compare(timeline.duration, 180);
            compare(browser.position, 90);
            verify(browser.isPlaying, "Playback was left paused after seeking");
            timeline.seek(0.25);
            wait(80);
            verify(timeline.seekable, "A second seek became unavailable");
            compare(browser.position, 45);
            compare(browser.playingSeeks, 0, "Firefox SetPosition must run while paused");
        }
        function test_paused_seek_stays_paused() {
            browser.isPlaying = false;
            timeline.seek(0.25);
            wait(50);
            compare(browser.position, 45);
            verify(!browser.isPlaying);
            compare(browser.pauseCalls, 0);
            compare(browser.playCalls, 0);
        }
        function test_local_player_seeks_without_pause() {
            browser.dbusName = "org.mpris.MediaPlayer2.mpv.test";
            browser.emulateBrokenSeek = false;
            timeline.seek(0.5);
            compare(browser.position, 90);
            verify(browser.isPlaying);
            compare(browser.pauseCalls, 0);
        }
        function test_latest_request_wins_while_pause_is_pending() {
            timeline.seek(0.2);
            timeline.seek(0.8);
            wait(80);
            compare(browser.position, 144);
            verify(browser.isPlaying);
            compare(browser.pauseCalls, 1);
        }
        function test_metadata_gap_keeps_known_duration_for_same_track() {
            browser.lengthSupported = false;
            browser.length = 0;
            wait(1);
            compare(timeline.duration, 180);
            verify(timeline.seekable);
        }
        function test_new_live_track_does_not_inherit_duration() {
            browser.uniqueId++;
            browser.lengthSupported = false;
            browser.length = 0;
            wait(1);
            compare(timeline.duration, 0);
            verify(!timeline.seekable);
        }
        function test_new_player_does_not_inherit_duration() {
            timeline.player = null;
            browser.lengthSupported = false;
            browser.length = 0;
            browser.uniqueId++;
            timeline.player = browser;
            wait(1);
            compare(timeline.duration, 0);
            verify(!timeline.seekable);
        }
        function test_track_change_during_pause_does_not_seek_new_track() {
            timeline.seek(0.5);
            browser.uniqueId++;
            wait(80);
            compare(browser.position, 10);
            verify(browser.isPlaying);
        }
        function test_unacknowledged_pause_times_out_without_stopping_playback() {
            browser.acknowledgePause = false;
            timeline.seek(0.5);
            wait(1600);
            verify(timeline.pendingPlayer === null);
            verify(browser.isPlaying);
            compare(browser.position, 10);
        }
        function test_unsupported_position_does_not_seek() {
            browser.positionSupported = false;
            timeline.seek(0.5);
            wait(50);
            compare(browser.position, 10);
            verify(!timeline.seekable);
            compare(browser.pauseCalls, 0);
        }
    }
}
