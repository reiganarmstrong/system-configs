// Exercise production popup sizing, notification lifetime and launcher reopening.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
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
    property int muteClicks: 0
    property var burstFirst: null
    property real burstStart: 0
    property real burstNext: 0
    property int burstSent: 0
    property var criticalBanner: null
    property var approvalBanner: null
    // Every change of the resizing popup's window visibility, with how opaque
    // its content was at that moment.
    property var visibilityLog: []
    // The same for the status menu, plus whether its page was loaded.
    property var menuLog: []
    property real approvalStart: 0
    QtObject { id: first; property string summary: "First" }
    QtObject { id: acceptAction; property string text: "Accept"; function invoke() {} }
    QtObject { id: second; property string summary: "Second"; property var actions: [acceptAction] }
    QtObject { id: third; property string summary: "Third" }
    NotificationPopups { id: banners }
    Launcher { id: appLauncher }
    StatusMenu {
        id: statusMenu
        name: "menu-test"
        page: Component { SubPanel { title: "Menu test"; Item { width: 10; height: 40 } } }
        onVisibleChanged: test.menuLog = [...test.menuLog,
            {visible: visible, open: open, loaded: pageItem !== null}]
    }
    Popup {
        id: resizingPopup
        name: "resize-test"
        Glass { id: surface; width: test.surfaceWidth; height: test.surfaceHeight }
        onVisibleChanged: test.visibilityLog = [...test.visibilityLog,
            {visible: visible, opacity: surface.parent.opacity}]
    }
    FloatingWindow {
        visible: true
        implicitWidth: 320
        implicitHeight: 100
        SliderTile { id: soundTile; width: 300; title: "Audit sound"; startIcon: "volume" }
    }
    Connections {
        target: soundTile
        ignoreUnknownSignals: true
        function onStartIconClicked() { test.muteClicks++; }
    }
    function sendBanner(summary, urgency = "normal") {
        Quickshell.execDetached(["notify-send", "--app-name=popup-regression", "--expire-time=0", "--urgency=" + urgency, summary]);
    }
    function findSlider(item) {
        if (item.accessibleName === "Audit sound") return item;
        for (const child of item.children ?? []) {
            const found = findSlider(child);
            if (found) return found;
        }
        return null;
    }

    function check(expected) {
        const regions = Array.from(banners.BackgroundEffect.blurRegion.regions);
        const actual = regions.map(region => region.item?.notification ?? null);
        if (actual.length !== expected.length || actual.some((notification, index) => notification !== expected[index])) {
            console.warn("FAILED: blur regions did not follow notification cards at step " + step);
            Qt.exit(1);
        }
    }

    function checkPopupBounds() {
        const regionItem = resizingPopup.blurShape.item;
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
            case 1:
                test.findSlider(soundTile).startIconClicked();
                if (test.muteClicks !== 1) {
                    console.warn("FAILED: sound tile did not forward its speaker-button click");
                    Qt.exit(1);
                    return;
                }
                Notifs.popups = [first];
                break;
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
                if (resizingPopup.BackgroundEffect.blurRegion !== resizingPopup.blurShape) {
                    console.warn("FAILED: an open popup is not blurred");
                    Qt.exit(1);
                    return;
                }
                ShellState.toggle("menu-test");
                if (resizingPopup.BackgroundEffect.blurRegion !== null || !resizingPopup.visible) {
                    console.warn("FAILED: a closing popup keeps its blur while it fades");
                    Qt.exit(1);
                    return;
                }
                break;
            case 10:
                if (resizingPopup.visible) { test.step--; break; }
                // Opened once, closed once: a hide while the content is still
                // drawn, or a second show, is a flash on closing.
                if (test.visibilityLog.length !== 2 || test.visibilityLog[1].visible
                        || test.visibilityLog[1].opacity > 0.01) {
                    console.warn("FAILED: popup window hid before its fade finished: "
                        + JSON.stringify(test.visibilityLog));
                    Qt.exit(1);
                    return;
                }
                if (!statusMenu.pageItem || statusMenu.pageItem.title !== "Menu test") {
                    console.warn("FAILED: a status menu did not load its page on opening");
                    Qt.exit(1);
                    return;
                }
                test.menuLog = [];
                ShellState.close();
                break;
            case 11:
                if (statusMenu.visible) { test.step--; break; }
                // One hide, at the end of the fade. An early hide unloads the
                // page and the reshown, refilled glass flashes as it closes.
                if (test.menuLog.length !== 1) {
                    console.warn("FAILED: status menu blinked while closing: " + JSON.stringify(test.menuLog));
                    Qt.exit(1);
                    return;
                }
                if (statusMenu.pageItem) {
                    console.warn("FAILED: a closed status menu kept its page loaded");
                    Qt.exit(1);
                    return;
                }
                break;
            case 12:
                if (appLauncher.apps.length < 60) { test.step--; break; }
                test.launcherList = test.findList(appLauncher.contentItem);
                ShellState.openPanel = "launcher";
                break;
            case 13:
                test.launcherList.positionViewAtEnd();
                appLauncher.selected = test.launcherList.count - 2;
                break;
            case 14:
                if (test.launcherList.contentY < 1000) {
                    console.warn("FAILED: launcher scroll fixture did not reach the bottom");
                    Qt.exit(1);
                }
                ShellState.close();
                break;
            case 15:
                if (appLauncher.visible) { test.step--; break; }
                ShellState.openPanel = "launcher";
                test.checkLauncherAtTop();
                break;
            case 16:
                test.checkLauncherAtTop();
                if (++test.reopenSamples < 10) { test.step--; break; }
                break;
            case 17:
                test.launcherList.positionViewAtEnd();
                appLauncher.selected = test.launcherList.count - 2;
                break;
            case 18:
                // Reopen before the closing fade has finished.
                ShellState.close();
                ShellState.openPanel = "launcher";
                test.checkLauncherAtTop();
                break;
            case 19:
                test.checkLauncherAtTop();
                test.launcherList.flick(0, -3500);
                break;
            case 20:
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
            case 21:
                test.checkLauncherAtTop();
                console.log("PASSED: notification blur, resizing popup bounds, status menus and launcher reopening");
                Prefs.values = Object.assign({}, Prefs.values, {bannerSeconds: 1});
                test.sendBanner("Burst first");
                break;
            case 22:
                test.burstFirst = Notifs.popups.find(n => n.summary === "Burst first") ?? null;
                if (!test.burstFirst) { test.step--; break; }
                test.burstStart = Date.now();
                break;
            case 23: {
                const elapsed = Date.now() - test.burstStart;
                if (elapsed < 1400) {
                    if (elapsed >= test.burstNext) {
                        test.sendBanner("Burst " + (++test.burstSent));
                        test.burstNext = elapsed + 180;
                    }
                    test.step--;
                }
                break;
            }
            case 24:
                if (Notifs.popups.includes(test.burstFirst)) {
                    console.warn("FAILED: new notifications reset an older banner's expiry");
                    Qt.exit(1);
                    return;
                }
                if (!Notifs.history.includes(test.burstFirst)) {
                    console.warn("FAILED: banner expiry removed notification history");
                    Qt.exit(1);
                    return;
                }
                Prefs.values = Object.assign({}, Prefs.values, {doNotDisturb: true});
                break;
            case 25:
                if (Notifs.popups.some(n => n.urgency !== NotificationUrgency.Critical)) {
                    console.warn("FAILED: enabling Focus left ordinary banners visible");
                    Qt.exit(1);
                    return;
                }
                test.sendBanner("Muted by Focus");
                test.sendBanner("Critical through Focus", "critical");
                break;
            case 26:
                test.criticalBanner = Notifs.popups.find(n => n.summary === "Critical through Focus") ?? null;
                if (!test.criticalBanner || !Notifs.history.some(n => n.summary === "Muted by Focus")) {
                    test.step--;
                    break;
                }
                if (Notifs.popups.some(n => n.summary === "Muted by Focus")) {
                    console.warn("FAILED: Focus did not suppress an ordinary banner");
                    Qt.exit(1);
                    return;
                }
                test.criticalBanner.dismiss();
                break;
            case 27:
                if (Notifs.popups.includes(test.criticalBanner)) {
                    console.warn("FAILED: a closed notification remained in the popup stack");
                    Qt.exit(1);
                    return;
                }
                Notifs.clearAll();
                console.log("PASSED: independent banner expiry, Focus and closed notifications");
                ShellState.openPanel = "control";
                Notifs.popups = [first, second];
                break;
            case 28:
                if (!banners.visible) {
                    console.warn("FAILED: control centre hides actionable pairing notifications");
                    Qt.exit(1);
                    return;
                }
                test.check([second]);
                ShellState.close();
                Notifs.replacePopups([]);
                console.log("PASSED: pairing notification actions remain reachable over control centre");
                Prefs.values = Object.assign({}, Prefs.values, {doNotDisturb: false});
                ShellState.openPanel = "control";
                Quickshell.execDetached(["notify-send", "--app-name=popup-regression", "--expire-time=0", "--action=confirm=Confirm", "Approval request"]);
                break;
            case 29:
                test.approvalBanner = Notifs.popups.find(n => n.summary === "Approval request") ?? null;
                if (!test.approvalBanner) { test.step--; break; }
                test.approvalStart = Date.now();
                break;
            case 30:
                if (Date.now() - test.approvalStart < 1400) { test.step--; break; }
                if (!Notifs.popups.includes(test.approvalBanner)) {
                    console.warn("FAILED: approval request expired before the user answered");
                    Qt.exit(1);
                    return;
                }
                Prefs.values = Object.assign({}, Prefs.values, {doNotDisturb: true});
                break;
            case 31:
                if (!Notifs.popups.includes(test.approvalBanner)) {
                    console.warn("FAILED: Focus hid approval for a control centre action");
                    Qt.exit(1);
                    return;
                }
                test.approvalBanner.actions[0].invoke();
                ShellState.close();
                Notifs.clearAll();
                console.log("PASSED: approval lifetime and Focus during interactive pairing");
                Qt.exit(0);
            }
        }
    }
}
