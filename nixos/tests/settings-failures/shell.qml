// Drives production Settings services and controls through failed, rejected
// and no-op changes with fake helpers. Exit code 0 means every check passed.
import QtQuick
import Quickshell
import qs.components.settings
import qs.modules.settings
import qs.services

ShellRoot {
    id: root
    property int step: 0
    property int waited: 0
    property int failures: 0
    property var mark: ({})
    property var filteredZones: ["UTC", "Europe/London"]

    function check(condition, message) {
        if (!condition) {
            failures++;
            console.warn("FAIL: " + message);
        } else
            console.log("ok: " + message);
    }
    function find(item, test) {
        if (test(item)) return item;
        for (const child of item.children ?? []) {
            const found = find(child, test);
            if (found) return found;
        }
        return null;
    }
    function switchOf(row) { return find(row, i => i.checkable !== undefined && i.toggle !== undefined); }
    function appRow(id) { return find(appsPage.item, i => i.modelData?.id === id && i.removing !== undefined); }
    function buttonIn(item, text) { return find(item, i => i.text === text && typeof i.click === "function"); }
    function titled(item, title) { return find(item, i => i.title === title && i.detail !== undefined); }
    function idle() { return !Prefs.saving && Prefs.queue.length === 0 && !SettingsAdmin.busy && SettingsAdmin.settling.length === 0; }

    FloatingWindow {
        implicitWidth: 640
        implicitHeight: 480
        visible: true
        color: "black"
        Column {
            width: 600
            SettingToggle { id: prefToggle; title: "Show seconds"; checked: Prefs.get("showSeconds", false); onToggled: v => Prefs.set("showSeconds", v) }
            SettingToggle { id: goodToggle; title: "24-hour clock"; checked: Prefs.get("clock24h", false); onToggled: v => Prefs.set("clock24h", v) }
            SettingToggle { id: noopToggle; title: "Refused locally"; checked: false; onToggled: v => {} }
            SettingToggle {
                id: adminToggle
                title: "Start broken app"
                checked: SettingsAdmin.get("apps", {startup: []}).startup.includes("broken")
                onToggled: v => SettingsAdmin.request("startup", {id: "broken", enabled: v})
            }
            SettingChoice {
                id: zone
                title: "Time zone"
                options: ["UTC", "Europe/London"]
                value: SettingsAdmin.get("time", {timezone: "UTC"}).timezone
                onChosen: v => SettingsAdmin.request("timezone", {zone: v})
            }
            SettingChoice {
                id: filtered
                title: "Filtered time zone"
                options: root.filteredZones
                value: "UTC"
            }
            Loader {
                id: appsPage
                active: false
                width: 600
                sourceComponent: AppsPage { host: root }
            }
        }
    }

    readonly property var steps: [
        () => Prefs.ready && idle(),
        () => {
            mark.filtered = find(filtered, i => i.delegateModel !== undefined && i.popup !== undefined);
            check(mark.filtered.currentIndex === 0, "dropdown starts on the stored value");
            // A search can hide the stored value; nothing else may then look selected.
            root.filteredZones = ["Europe/London"];
            return true;
        },
        () => {
            check(mark.filtered.currentIndex === -1, "filtered dropdown without the stored value selects nothing: " + mark.filtered.currentIndex);
            root.filteredZones = ["Europe/London", "UTC"];
            return true;
        },
        () => {
            check(mark.filtered.currentIndex === 1, "dropdown follows the stored value when it returns: " + mark.filtered.currentIndex);
            return true;
        },
        () => { SettingsAdmin.refresh("apps"); SettingsAdmin.refresh("time"); return true; },
        () => idle() && SettingsAdmin.get("apps", null) !== null,
        () => { switchOf(prefToggle).click(); return true; },
        () => idle() && !Prefs.get("showSeconds", false),
        () => {
            // Finding 1: the resync after a failed save keeps the error.
            check(Prefs.error === "Simulated save failure", "failed save error survives the resync: '" + Prefs.error + "'");
            check(!switchOf(prefToggle).checked, "preference switch shows the saved value after a failed save");
            switchOf(goodToggle).click();
            return true;
        },
        () => idle() && Prefs.values.clock24h === true,
        () => {
            check(Prefs.error === "", "a successful save clears the earlier error");
            check(switchOf(goodToggle).checked, "accepted preference switch is on");
            switchOf(noopToggle).click();
            return true;
        },
        () => {
            check(!switchOf(noopToggle).checked, "switch whose change was refused stays off");
            mark.serial = SettingsAdmin.get("apps", {}).serial;
            switchOf(adminToggle).click();
            return true;
        },
        () => idle(),
        () => {
            check(!switchOf(adminToggle).checked, "admin switch stays off after a failed change");
            check(SettingsAdmin.error === "Simulated startup failure", "admin failure is still shown after its refresh: '" + SettingsAdmin.error + "'");
            check(SettingsAdmin.get("apps", {}).serial > mark.serial, "failed change refreshed its section");
            const box = find(zone, i => i.delegateModel !== undefined && i.popup !== undefined);
            mark.box = box;
            box.popup.open();
            return true;
        },
        () => mark.box.popup.opened,
        () => {
            const item = mark.box.popup.contentItem.itemAtIndex(1);
            item.click();
            check(mark.box.currentIndex === 0, "dropdown keeps showing the current zone while the change is pending");
            check(SettingsAdmin.mutating, "time zone change is in progress");
            mark.storage = SettingsAdmin.get("storage", {serial: 0}).serial;
            SettingsAdmin.refresh("storage");
            return true;
        },
        () => SettingsAdmin.get("storage", {serial: 0}).serial > mark.storage,
        () => {
            // Finding 7: snapshots are not queued behind a change awaiting authentication.
            check(SettingsAdmin.mutating, "unrelated snapshot finished while the change was still waiting");
            return true;
        },
        () => idle(),
        () => {
            check(SettingsAdmin.error === "", "cancelled authentication is not shown as an error");
            check(SettingsAdmin.notice.indexOf("cancelled") >= 0, "cancelled authentication is reported neutrally");
            check(mark.box.currentIndex === 0, "dropdown shows the unchanged zone after cancellation");
            const t = AppLaunch.terminalCommand;
            check(JSON.stringify(t("ghostty --new-window", ["htop"])) === '["ghostty","-e","htop"]', "TERMINAL with arguments is not used as one executable name");
            check(JSON.stringify(t("/run/current-system/sw/bin/foot", ["vim", "a b.txt"])) === '["/run/current-system/sw/bin/foot","-e","vim","a b.txt"]', "TERMINAL path keeps program arguments intact");
            check(JSON.stringify(t(undefined, ["htop"])) === '["ghostty","-e","htop"]', "unset TERMINAL uses Ghostty");
            check(t("-e", ["x"])[0] === "ghostty", "option-like TERMINAL is rejected");
            return true;
        },
        () => {
            // Errors must still be visible a moment later, not only for a frame.
            check(Prefs.error === "" && SettingsAdmin.notice !== "", "final state is stable");
            appsPage.active = true;
            return true;
        },
        () => idle() && appsPage.item && appRow("org.test.Fixture") !== null,
        () => {
            // Finding 5: confirmations and details open inside the row of the app they concern.
            const row = appRow("org.test.Fixture");
            mark.row = row;
            buttonIn(row, "Remove…").click();
            const confirm = titled(row, "Remove Fixture?");
            check(confirm !== null && confirm.visible, "remove confirmation opens inside the app's own row");
            check(!titled(appRow("org.test.Other"), "Remove Other?").visible, "other apps show no confirmation");
            buttonIn(row, "Permissions").click();
            return true;
        },
        () => idle() && mark.row.loaded,
        () => {
            const details = titled(mark.row, "Permissions");
            check(details.visible && details.detail.indexOf("Network access allowed") === 0, "permissions are listed under the app: '" + details.detail + "'");
            check(buttonIn(mark.row, "Hide permissions") !== null, "the permissions button can hide them again");
            check(!titled(appRow("org.test.Other"), "Permissions").visible, "other apps keep their permissions hidden");
            console.log(failures ? "FAILED: " + failures : "PASSED");
            Qt.exit(failures ? 1 : 0);
            return false;
        }
    ]
    Timer {
        interval: 20
        repeat: true
        running: true
        onTriggered: {
            if (++root.waited > 500) {
                console.warn("FAIL: timed out at step " + root.step);
                Qt.exit(2);
            }
            if (root.steps[root.step]()) {
                root.step++;
                root.waited = 0;
            }
        }
    }
}
