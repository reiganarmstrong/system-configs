pragma Singleton
// The notification daemon. New notifications show as popups, then move to
// the history in the notification centre. Do Not Disturb sends them there
// directly.
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    property bool doNotDisturb: false
    // Notifications currently shown as popups.
    property list<QtObject> popups: []
    readonly property var history: server.trackedNotifications.values

    function dismissPopup(notification: var) {
        popups = popups.filter(n => n !== notification);
    }
    function clearAll() {
        for (const n of [...history])
            n.dismiss();
        popups = [];
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notification => {
            notification.tracked = true;
            if (!root.doNotDisturb || notification.urgency === NotificationUrgency.Critical)
                root.popups = [...root.popups, notification];
        }
    }
}
