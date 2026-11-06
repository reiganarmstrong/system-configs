"""Boundary checks for desktop preferences and monitor rollback safety."""
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("settings", sys.argv.pop(1))
s = importlib.util.module_from_spec(spec)
spec.loader.exec_module(s)


class SettingsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.env = patch.dict(os.environ, {"XDG_STATE_HOME": self.tmp.name, "HYPRLAND_INSTANCE_SIGNATURE": "test"})
        self.env.start()
        os.environ.pop("DESKTOP_SETTINGS_DEFAULTS", None)

    def tearDown(self):
        self.env.stop()
        self.tmp.cleanup()

    def test_rejects_invalid_preferences_before_writing(self):
        for value in [{"pointerSpeed": True}, {"repeatRate": 1000}, {"panelOpacity": float("nan")},
                      {"keyboardLayout": "us\";os.execute('bad')"}, {"unrecognized": 1}, {"reduceMotion": 1}]:
            with self.assertRaises(ValueError):
                s.save(value)
        self.assertFalse((s.state_dir() / "preferences.json").exists())

    def test_idle_never_blanks_before_locking(self):
        with self.assertRaises(ValueError):
            s.save({"lockMinutes": 10, "screenOffMinutes": 5})
        with self.assertRaises(ValueError):
            s.save({"screenOffMinutes": 30, "suspendMinutes": 15})
        result = s.validate({"screenOffMinutes": 30, "suspendMinutes": 0})
        self.assertNotIn("systemctl suspend", s.idle_config(result))

    def test_failed_live_change_preserves_saved_preferences(self):
        s.write_json("preferences.json", {"pointerSpeed": 0.2})
        with patch.object(s, "eval_hypr", side_effect=[RuntimeError("compositor rejected"), None]):
            with self.assertRaises(RuntimeError):
                s.save({"pointerSpeed": 0.5})
        self.assertEqual(s.read_json("preferences.json", {}), {"pointerSpeed": 0.2})

    def test_saved_overrides_do_not_freeze_nix_defaults(self):
        with patch.object(s, "eval_hypr"):
            s.save({"pointerSpeed": 0.3})
        self.assertEqual(s.read_json("preferences.json", {}), {"pointerSpeed": 0.3})
        script = (s.state_dir() / "settings.lua").read_text()
        self.assertNotIn("repeat_rate", script)
        self.assertIn("sensitivity", script)
        defaults_file = Path(self.tmp.name) / "defaults.json"
        defaults_file.write_text(json.dumps({"rounding": 20, "suspendMinutes": 0}))
        with patch.dict(os.environ, {"DESKTOP_SETTINGS_DEFAULTS": str(defaults_file)}):
            values = s.validate(s.read_json("preferences.json", {}))
        self.assertEqual(values["pointerSpeed"], 0.3)
        self.assertEqual(values["rounding"], 20)
        self.assertEqual(values["suspendMinutes"], 0)

    def test_corrupt_state_is_reported_without_overwriting(self):
        s.atomic_write("preferences.json", "not json")
        with self.assertRaises(json.JSONDecodeError):
            s.save({"showSeconds": True})
        self.assertEqual((s.state_dir() / "preferences.json").read_text(), "not json")

    def test_expired_display_preview_cannot_be_confirmed(self):
        s.write_json("display-pending.json", {"token": "expired", "expires": 0})
        with self.assertRaises(ValueError):
            s.keep_display("expired")
        self.assertFalse((s.state_dir() / "displays.json").exists())

    def test_only_matching_preview_can_revert(self):
        old = {"output": "Virtual-1", "mode": "1440x960@75", "scale": 1, "position": "0x0", "transform": 0}
        s.write_json("display-pending.json", {"token": "actual", "old": old})
        with patch.object(s, "eval_hypr") as execute, patch.object(s, "verify_display"):
            s.revert_display("stale")
            execute.assert_not_called()
            s.revert_display("actual")
            execute.assert_called_once_with(s.monitor_lua(old))
        self.assertEqual(s.read_json("display-pending.json", {}), {})

    def test_failed_rollback_keeps_recovery_record(self):
        s.write_json("display-pending.json", {"token": "actual", "old": {"output": "Virtual-1"}})
        with patch.object(s, "eval_hypr"), patch.object(s, "verify_display", side_effect=RuntimeError("driver refused")):
            with self.assertRaises(RuntimeError):
                s.revert_display("actual")
        self.assertEqual(s.read_json("display-pending.json", {})["token"], "actual")

    def test_fixed_virtual_mode_rejects_resolution_change_before_applying(self):
        monitor = {"name": "Virtual-1", "width": 1440, "height": 960, "refreshRate": 75,
                   "scale": 1, "x": 0, "y": 0, "transform": 0, "availableModes": ["1280x960@60.00Hz"]}
        with patch.dict(os.environ, {"DESKTOP_SETTINGS_FIXED_MODE": "1"}), patch.object(s, "monitors", return_value=[monitor]), patch.object(s, "eval_hypr") as apply:
            with self.assertRaises(ValueError):
                s.preview_display({"output": "Virtual-1", "mode": "1280x960@60.00", "scale": 1, "transform": 0})
            apply.assert_not_called()
        self.assertFalse((s.state_dir() / "display-pending.json").exists())

    def test_reset_preserves_confirmed_monitor_and_account_state(self):
        displays = {"Virtual-1": {"output": "Virtual-1", "mode": "1440x960@75", "scale": 1}}
        s.write_json("displays.json", displays)
        with patch.object(s, "eval_hypr"):
            s.save({"showSeconds": True})
            s.save(s.defaults())
        self.assertEqual(s.read_json("preferences.json", None), {})
        self.assertEqual(s.read_json("displays.json", {}), displays)


unittest.main()
