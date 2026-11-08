import QtQuick
import QtTest
import "ddc.js" as Ddc

TestCase {
    name: "Ddc"

    // `ddcutil detect` with an external monitor, the laptop panel (which has
    // no DDC/CI) and a second monitor with DDC/CI turned off.
    readonly property string detect: [
        "Display 1",
        "   I2C bus:  /dev/i2c-7",
        "   DRM_connector:           card1-DP-3",
        "   EDID synopsis:",
        "      Mfg id:               DEL - Dell Inc.",
        "      Model:                DELL U2723QE",
        "   VCP version:         2.1",
        "",
        "Invalid display",
        "   I2C bus:  /dev/i2c-4",
        "   DRM_connector:           card1-eDP-1",
        "   EDID synopsis:",
        "      Model:                BOE",
        "   This is a laptop display.  Laptop displays do not support DDC/CI.",
        "",
        "Display 2",
        "   I2C bus:  /dev/i2c-9",
        "   DRM_connector:           card1-HDMI-A-1",
        "   VCP version:         2.2",
        ""
    ].join("\n")

    function test_detect() {
        compare(Ddc.parseDetect(detect), [{bus: 7, output: "DP-3"}, {bus: 9, output: "HDMI-A-1"}]);
    }
    function test_detect_without_connector() {
        // Non-DRM drivers report no connector; such a display can't be matched to an output.
        compare(Ddc.parseDetect("Display 1\n   I2C bus:  /dev/i2c-3\n"), []);
    }
    function test_detect_nothing() {
        compare(Ddc.parseDetect("No displays found.\n"), []);
    }

    function test_levels() {
        const levels = Ddc.parseLevels("7 VCP 10 C 40 100\n9 \n11 VCP 10 C 12 60\n");
        compare(levels, {"7": {current: 40, max: 100}, "11": {current: 12, max: 60}});
    }
    function test_levels_reject_zero_max() {
        compare(Ddc.parseLevels("7 VCP 10 C 0 0\n"), {});
    }

    function test_pick_focused_monitor() {
        compare(Ddc.pickTarget({builtin: {}, "DP-3": {}}, "DP-3"), "DP-3");
    }
    function test_pick_falls_back_to_panel() {
        compare(Ddc.pickTarget({builtin: {}, "DP-3": {}}, "eDP-1"), "builtin");
        compare(Ddc.pickTarget({builtin: {}}, "HDMI-A-1"), "builtin");
    }
    function test_pick_nothing_adjustable() {
        compare(Ddc.pickTarget({}, "DP-3"), "");
        compare(Ddc.pickTarget({"DP-3": {}}, "HDMI-A-1"), "");
    }
}
