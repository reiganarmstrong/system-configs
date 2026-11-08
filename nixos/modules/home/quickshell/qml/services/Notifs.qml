pragma Singleton
// The notification daemon. New notifications show as popups, then move to
// the history in the notification centre. Do Not Disturb sends them there
// directly.
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    readonly property bool doNotDisturb: Prefs.get("doNotDisturb", false)
    // Notifications currently shown as popups.
    property list<QtObject> popups: []
    readonly property var history: server.trackedNotifications.values
    property var popupStarted: new Map()

    function needsResponse(notification: var): bool {
        return (notification.actions?.length ?? 0) > 0 && notification.expireTimeout === 0;
    }
    function allowed(notification: var): bool {
        return !doNotDisturb || notification.urgency === NotificationUrgency.Critical
            || (["control", "bluetooth"].includes(ShellState.openPanel) && needsResponse(notification));
    }

    function replacePopups(next: var) {
        if (next.length !== popups.length || next.some((n, i) => n !== popups[i]))
            popups = next;
        const active = new Set(next);
        for (const n of popupStarted.keys())
            if (!active.has(n)) popupStarted.delete(n);
    }

    function dismissPopup(notification: var) {
        replacePopups(popups.filter(n => n !== notification));
    }
    function clearAll() {
        for (const n of [...history])
            n.dismiss();
        replacePopups([]);
    }

    // Keep expiry with the notification, not its delegate. Updating the
    // popup list can recreate cards and restart timers inside those cards.
    Timer {
        interval: 100
        running: root.popups.length > 0 && Prefs.get("bannerSeconds", 6) > 0
        repeat: true
        onTriggered: {
            const cutoff = Date.now() - Prefs.get("bannerSeconds", 6) * 1000;
            root.replacePopups(root.popups.filter(n => n
                && (root.needsResponse(n) || !root.popupStarted.has(n) || root.popupStarted.get(n) > cutoff)));
        }
    }
    onHistoryChanged: replacePopups(popups.filter(n => n && history.includes(n)))
    onDoNotDisturbChanged: if (doNotDisturb)
        replacePopups(popups.filter(n => n && allowed(n)))

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notification => {
            notification.tracked = true;
            if (root.allowed(notification)) {
                root.popupStarted.set(notification, Date.now());
                root.popups = [...root.popups, notification];
            }
        }
    }
}
