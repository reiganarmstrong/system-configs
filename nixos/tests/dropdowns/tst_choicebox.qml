import QtQuick
import QtTest
import qs.components

Item {
    width: 640
    height: 480
    ChoiceBox { id: choice; x: 60; y: 60; options: ["First", "Second", "Third"] }
    ChoiceBox { id: other; x: 340; y: 60; options: ["Other", "Another"] }
    TestCase {
        name: "DropdownLifecycle"
        when: windowShown

        function clickField(field, holdMs) {
            mousePress(field, 100, 18);
            wait(holdMs);
            mouseRelease(field, 100, 18);
        }
        function cleanup() {
            choice.popup.close();
            other.popup.close();
            wait(130);
            Motion.reduced = false;
            choice.currentIndex = 0;
        }
        function test_repeated_close_stays_closed_data() {
            return [
                {tag: "fast", holdMs: 0, reduced: false},
                {tag: "short", holdMs: 25, reduced: false},
                {tag: "held-past-fade", holdMs: 110, reduced: false},
                {tag: "long-held", holdMs: 200, reduced: false},
                {tag: "reduced-motion", holdMs: 110, reduced: true}
            ];
        }
        function test_repeated_close_stays_closed(data) {
            Motion.reduced = data.reduced;
            for (let i = 0; i < 8; i++) {
                clickField(choice, data.holdMs);
                tryCompare(choice.popup, "opened", true);
                // The press must last longer than the exit animation to catch
                // an outside-press close followed by a release-triggered reopen.
                clickField(choice, data.holdMs);
                wait(140);
                verify(!choice.popup.visible, "Close click reopened at cycle " + i);
            }
        }
        function test_click_outside_dismisses() {
            clickField(choice, 30);
            tryCompare(choice.popup, "opened", true);
            mouseClick(parent, 30, 420);
            tryCompare(choice.popup, "visible", false);
        }
        function test_switch_dropdown_dismisses_previous() {
            clickField(choice, 30);
            tryCompare(choice.popup, "opened", true);
            clickField(other, 110);
            tryCompare(choice.popup, "visible", false);
            tryCompare(other.popup, "opened", true);
        }
        function test_escape_dismisses() {
            clickField(choice, 30);
            tryCompare(choice.popup, "opened", true);
            keyClick(Qt.Key_Escape);
            tryCompare(choice.popup, "visible", false);
        }
        function test_keyboard_selection() {
            choice.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Space);
            tryCompare(choice.popup, "opened", true);
            keyClick(Qt.Key_Down);
            keyClick(Qt.Key_Return);
            compare(choice.currentIndex, 1);
            tryCompare(choice.popup, "visible", false);
        }
        function test_pointer_selection() {
            clickField(choice, 30);
            tryCompare(choice.popup, "opened", true);
            const list = choice.popup.contentItem;
            mouseClick(list, 100, choice.optionHeight + 20);
            compare(choice.currentIndex, 1);
            tryCompare(choice.popup, "visible", false);
        }
    }
}
