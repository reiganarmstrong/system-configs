// Exercise production popup sizing, notification lifetime and launcher reopening.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.modules
import qs.services

ShellRoot {
    id: test
    property int step: 0
    property real surfaceWidth: 320
    property real surfaceHeight: 480
    property var launcherList: null
    property int reopenSamples: 0
    QtObject { id: first; property string summary: "First" }
    QtObject { id: second; property string summary: "Second" }
    QtObject { id: third; property string summary: "Third" }
    NotificationPopups { id: banners }
    Launcher { id: appLauncher }
    Popup {
        id: resizingPopup
        name: "resize-test"
        Glass { id: surface; width: test.surfaceWidth; height: test.surfaceHeight }
    }
    FloatingWindow { visible: true; implicitWidth: 100; implicitHeight: 100 }

    function check(expected) {
        const regions = Array.from(banners.BackgroundEffect.blurRegion.regions);
        const actual = regions.map(region => region.item?.notification ?? null);
        if (actual.length !== expected.length || actual.some((notification, index) => notification !== expected[index])) {
            console.warn("FAILED: blur regions did not follow notification cards at step " + step);
            Qt.exit(1);
        }
    }

    function checkPopupBounds() {
        const regionItem = resizingPopup.BackgroundEffect.blurRegion.item;
        if (regionItem.width !== surface.width || regionItem.height !== surface.height) {
            console.warn("FAILED: popup blur bounds " + regionItem.width + "x" + regionItem.height
                + " extend past glass " + surface.width + "x" + surface.height);
            Qt.exit(1);
        }
    }

    function findList(item) {
        if (typeof item.positionViewAtBeginning === "function") return item;
        for (const child of item.children ?? []) {
            const found = findList(child);
            if (found) return found;
        }
        return null;
    }

    function checkLauncherAtTop() {
        if (Math.abs(launcherList.contentY - launcherList.originY) > 1) {
            console.warn("FAILED: reopened launcher is scrolling from " + launcherList.contentY
                + " instead of starting at " + launcherList.originY);
            Qt.exit(1);
        }
    }

    Timer {
        interval: 50
        running: true
        repeat: true
        onTriggered: {
            switch (++test.step) {
            case 1: Notifs.popups = [first]; break;
            case 2: test.check([first]); Notifs.popups = [first, second]; break;
            case 3: test.check([first, second]); Notifs.popups = [second, third]; break;
            case 4: test.check([second, third]); Notifs.popups = [third]; break;
            case 5: test.check([third]); Notifs.popups = []; break;
            case 6:
                test.check([]);
                ShellState.openPanel = "resize-test";
                break;
            case 7:
                test.checkPopupBounds();
                test.surfaceWidth = 240;
                test.surfaceHeight = 180;
                break;
            case 8:
                test.checkPopupBounds();
                test.surfaceWidth = 360;
                test.surfaceHeight = 520;
                break;
            case 9:
                test.checkPopupBounds();
                ShellState.close();
                break;
            case 10:
                if (appLauncher.apps.length < 60) { test.step--; break; }
                test.launcherList = test.findList(appLauncher.contentItem);
                ShellState.openPanel = "launcher";
                break;
            case 11:
                test.launcherList.positionViewAtEnd();
                appLauncher.selected = test.launcherList.count - 2;
                break;
            case 12:
                if (test.launcherList.contentY < 1000) {
                    console.warn("FAILED: launcher scroll fixture did not reach the bottom");
                    Qt.exit(1);
                }
                ShellState.close();
                break;
            case 13:
                if (appLauncher.visible) { test.step--; break; }
                ShellState.openPanel = "launcher";
                test.checkLauncherAtTop();
                break;
            case 14:
                test.checkLauncherAtTop();
                if (++test.reopenSamples < 10) { test.step--; break; }
                break;
            case 15:
                test.launcherList.positionViewAtEnd();
                appLauncher.selected = test.launcherList.count - 2;
                break;
            case 16:
                // Reopen before the closing fade has finished.
                ShellState.close();
                ShellState.openPanel = "launcher";
                test.checkLauncherAtTop();
                break;
            case 17:
                test.checkLauncherAtTop();
                test.launcherList.flick(0, -3500);
                break;
            case 18:
                if (!test.launcherList.flicking) {
                    console.warn("FAILED: launcher flick fixture did not start scrolling");
                    Qt.exit(1);
                }
                ShellState.close();
                ShellState.openPanel = "launcher";
                test.checkLauncherAtTop();
                if (test.launcherList.flicking) {
                    console.warn("FAILED: old flick momentum survives launcher reopening");
                    Qt.exit(1);
                }
                break;
            case 19:
                test.checkLauncherAtTop();
                console.log("PASSED: notification blur, resizing popup bounds and launcher reopening");
                Qt.exit(0);
            }
        }
    }
}
