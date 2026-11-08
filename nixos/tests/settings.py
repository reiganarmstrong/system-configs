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
        self.env = patch.dict(os.environ, {"XDG_STATE_HOME": self.tmp.name})
        self.env.start()
        os.environ.pop("DESKTOP_SETTINGS_DEFAULTS", None)
        os.environ.pop("DESKTOP_SETTINGS_DISPLAY", None)

    def tearDown(self):
        self.env.stop()
        self.tmp.cleanup()

    def test_hyprland_preferences_and_monitors(self):
        text = s.settings_lua(s.validate({"cursorSize": 32, "reduceMotion": True}), {})
        self.assertIn('hl.env("XCURSOR_SIZE", "32")', text)
        # Hyprland's own options belong to hyprland.lua and HyprMod.
        self.assertNotIn("hl.config", text)
        s.check_lua(text)
        self.assertEqual(s.normalize_hypr_mode("2560x1440@144.00000Hz"), "2560x1440@144.000Hz")
        monitor = {"name":"DP-1", "width":2560, "height":1440, "refreshRate":143.998,
                   "scale":1.25, "x":0, "y":0, "transform":0, "availableModes":["2560x1440@144.000Hz"]}
        with patch.dict(os.environ, {"HYPRLAND_INSTANCE_SIGNATURE":"audit"}), patch.object(s,"run",return_value=json.dumps([monitor])) as run:
            result = s.monitors()[0]
            self.assertEqual(result["width"], 2560)
            self.assertEqual(result["refreshRate"], 144.0)
            self.assertEqual(result["availableModes"], monitor["availableModes"])
            run.assert_called_once_with(["hyprctl", "-j", "monitors"])

    def test_idle_dispatches_through_active_compositor(self):
        text = s.idle_config(s.defaults())
        self.assertIn("desktop-compositor power-on", text)
        self.assertIn("desktop-compositor power-off", text)

    def test_hyprland_reload_failure_restores_saved_files(self):
        with patch.dict(os.environ, {"HYPRLAND_INSTANCE_SIGNATURE":"audit"}), patch.object(s, "reload_hyprland", side_effect=[RuntimeError("IPC failure"), None]), \
                patch.object(s, "apply_appearance"):
            with self.assertRaisesRegex(RuntimeError, "IPC failure"):
                s.save({"cursorSize": 32})
        for name in s.ARTIFACTS:
            self.assertFalse((s.state_dir() / name).exists(), name)

    def test_rejects_invalid_preferences_before_writing(self):
        for value in [{"bannerSeconds": True}, {"lockMinutes": 1000}, {"panelOpacity": float("nan")},
                      {"wallpaper": "/tmp/x\";os.execute('bad')"}, {"unrecognized": 1}, {"reduceMotion": 1}]:
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

    def test_compositor_rejection_preserves_saved_state(self):
        s.write_json("preferences.json", {"cursorSize": 32})
        with patch.object(s, "check_lua", side_effect=RuntimeError("Hyprland rejected the settings")):
            with self.assertRaises(RuntimeError):
                s.save({"cursorSize": 40})
        self.assertEqual(s.read_json("preferences.json", {}), {"cursorSize": 32})
        self.assertFalse((s.state_dir() / "settings.lua").exists())

    def test_generated_settings_are_accepted_by_hyprland(self):
        flipped = {key: not value for key, value in s.defaults().items() if type(value) is bool}
        for values in [{}, flipped, {"cursorSize": 64}]:
            with self.subTest(values=values):
                s.check_lua(s.settings_lua(s.validate(values)))
        with self.assertRaises(RuntimeError):
            s.check_lua('hl.config({input={nonexistent_option=true}})')

    def test_outputs_come_from_nix_then_confirmed_choices(self):
        display = {"output": "eDP-1", "mode": "2880x1920", "scale": 2}
        confirmed = {"output": "HDMI-A-1", "mode": "1920x1080@60.000", "scale": 1, "transform": 1}
        with patch.dict(os.environ, {"DESKTOP_SETTINGS_DISPLAY": json.dumps(display)}):
            text = s.settings_lua(s.defaults(), {"HDMI-A-1": confirmed})
            s.check_lua(text)
            self.assertIn('["output"]="eDP-1"', text)
            self.assertIn('["scale"]=2', text)
            self.assertIn('["transform"]=1', text)
            kept = s.settings_lua(s.defaults(), {"eDP-1": display | {"mode": "2880x1920@120.000", "transform": 0}})
            self.assertEqual(kept.count('["output"]="eDP-1"'), 1)
            self.assertIn('["mode"]="2880x1920@120.000"', kept)
        with patch.dict(os.environ, {"DESKTOP_SETTINGS_DISPLAY": json.dumps({"output": "", "mode": "preferred", "scale": 1})}):
            self.assertNotIn('hl.monitor(', s.settings_lua(s.defaults(), {}))

    def test_saved_overrides_do_not_freeze_nix_defaults(self):
        with patch.object(s, "apply_appearance"):
            s.save({"cursorSize": 32})
        self.assertEqual(s.read_json("preferences.json", {}), {"cursorSize": 32})
        self.assertIn('"XCURSOR_SIZE", "32"', (s.state_dir() / "settings.lua").read_text())
        defaults_file = Path(self.tmp.name) / "defaults.json"
        defaults_file.write_text(json.dumps({"bannerSeconds": 9, "suspendMinutes": 0}))
        with patch.dict(os.environ, {"DESKTOP_SETTINGS_DEFAULTS": str(defaults_file)}):
            values = s.validate(s.read_json("preferences.json", {}))
        self.assertEqual(values["cursorSize"], 32)
        self.assertEqual(values["bannerSeconds"], 9)
        self.assertEqual(values["suspendMinutes"], 0)

    def test_accessibility_values_are_validated(self):
        for value in [{"textScale":float("nan")},{"textScale":2.0},{"cursorSize":True},{"cursorSize":100}]:
            with self.assertRaises(ValueError): s.save(value)

    def test_appearance_failure_preserves_saved_preferences(self):
        s.write_json("preferences.json", {"textScale":1.15})
        with patch.object(s,"apply_appearance",side_effect=[RuntimeError("desktop rejected"),None]):
            with self.assertRaises(RuntimeError):s.save({"textScale":1.25})
        self.assertEqual(s.read_json("preferences.json",{}), {"textScale":1.15})

    def test_retired_hyprland_options_are_dropped_on_save(self):
        s.write_json("preferences.json", {"gaps": 12, "keyboardLayout": "gb", "showSeconds": True})
        s.save(s.validate(s.read_json("preferences.json", {})) | {"clock24h": True})
        self.assertEqual(s.read_json("preferences.json", {}), {"showSeconds": True, "clock24h": True})
        defaults_file = Path(self.tmp.name) / "defaults.json"
        defaults_file.write_text(json.dumps({"rounding": 20}))
        with patch.dict(os.environ, {"DESKTOP_SETTINGS_DEFAULTS": str(defaults_file)}):
            self.assertNotIn("rounding", s.defaults())

    def test_corrupt_state_is_reported_without_overwriting(self):
        s.atomic_write("preferences.json", "not json")
        with self.assertRaises(ValueError):
            s.save({"showSeconds": True})
        self.assertEqual((s.state_dir() / "preferences.json").read_text(), "not json")

    def test_expired_display_preview_cannot_be_confirmed(self):
        s.write_json("display-pending.json", {"token": "expired", "expires": 0})
        with self.assertRaises(ValueError):
            s.keep_display("expired")
        self.assertFalse((s.state_dir() / "displays.json").exists())

    def test_only_matching_preview_can_revert(self):
        old = {"output": "Virtual-1", "mode": "1440x960@75.000", "scale": 1, "transform": 0}
        s.write_json("display-pending.json", {"token": "actual", "old": old})
        with patch.object(s, "apply_display") as execute, patch.object(s, "verify_display"), \
             patch.object(s, "monitors", return_value=[{"name": "Virtual-1"}]):
            s.revert_display("stale")
            execute.assert_not_called()
            s.revert_display("actual")
            execute.assert_called_once_with(old)
        self.assertEqual(s.read_json("display-pending.json", {}), {})

    def test_failed_rollback_keeps_recovery_record(self):
        s.write_json("display-pending.json", {"token": "actual", "old": {"output": "Virtual-1"}})
        with patch.object(s, "apply_display"), patch.object(s, "verify_display", side_effect=RuntimeError("driver refused")), \
             patch.object(s, "monitors", return_value=[{"name": "Virtual-1"}]):
            with self.assertRaises(RuntimeError):
                s.revert_display("actual")
        self.assertEqual(s.read_json("display-pending.json", {})["token"], "actual")

    def test_fixed_virtual_mode_rejects_resolution_change_before_applying(self):
        monitor = {"name": "Virtual-1", "width": 1440, "height": 960, "refreshRate": 75,
                   "scale": 1, "x": 0, "y": 0, "transform": 0, "availableModes": ["1440x960@75.000Hz", "1280x960@60.000Hz"]}
        with patch.dict(os.environ, {"DESKTOP_SETTINGS_FIXED_MODE": "1"}), patch.object(s, "monitors", return_value=[monitor]), patch.object(s, "apply_display") as apply:
            with self.assertRaises(ValueError):
                s.preview_display({"output": "Virtual-1", "mode": "1280x960@60.000", "scale": 1, "transform": 0})
            apply.assert_not_called()
        self.assertFalse((s.state_dir() / "display-pending.json").exists())

    # Fault injection at each boundary of the save transaction. Every case
    # starts from saved state that differs from defaults, so a partial commit
    # or a missed rollback is visible in the files and the live calls.
    # Restoring settings.lua and reloading reverses compositor changes.
    def seed(self):
        with patch.object(s, "apply_appearance"), patch.object(s, "run"):
            s.save({"textScale": 1.15, "cursorSize": 32, "lockMinutes": 4, "screenOffMinutes": 6})
        return {name: (s.state_dir() / name).read_text() for name in s.ARTIFACTS}

    def assert_unchanged(self, before):
        self.assertEqual({name: (s.state_dir() / name).read_text() for name in s.ARTIFACTS}, before)

    def failing_write(self, failing_name):
        real = s.atomic_write
        def write(name, text):
            if name == failing_name:
                raise OSError("simulated ENOSPC for " + name)
            real(name, text)
        return write

    def test_each_write_failure_restores_files_and_live_state(self):
        for name in s.ARTIFACTS:
            with self.subTest(failing=name):
                before = self.seed()
                appearance = []
                with patch.object(s, "apply_appearance", side_effect=lambda p: appearance.append(p["textScale"])), \
                     patch.object(s, "run") as run, patch.object(s, "atomic_write", self.failing_write(name)):
                    with self.assertRaisesRegex(OSError, "ENOSPC"):
                        s.save(s.validate({"textScale": 1.25, "cursorSize": 40, "lockMinutes": 2, "screenOffMinutes": 6}))
                    run.assert_not_called()  # hypridle is only restarted after a commit
                self.assert_unchanged(before)
                self.assertEqual(appearance, [1.25, 1.15])

    def test_failed_first_save_removes_new_files(self):
        with patch.object(s, "apply_appearance"), \
             patch.object(s, "atomic_write", self.failing_write("idle.conf")):
            with self.assertRaises(OSError):
                s.save({"showSeconds": True})
        self.assertEqual(sorted(p.name for p in s.state_dir().iterdir() if not p.name.startswith(".")), [])

    def test_backup_read_failure_restores_live_state_without_writing(self):
        for failing_name in s.ARTIFACTS:
            with self.subTest(failing=failing_name):
                before = self.seed()
                real_read = s.read_text
                def read(name):
                    if name == failing_name:
                        raise PermissionError("cannot read " + name)
                    return real_read(name)
                appearance = []
                with patch.object(s, "read_text", side_effect=read), \
                     patch.object(s, "apply_appearance", side_effect=lambda p: appearance.append(p["textScale"])), \
                     patch.object(s, "atomic_write") as write:
                    with self.assertRaisesRegex(PermissionError, failing_name):
                        s.save({"textScale": 1.25, "cursorSize": 40})
                    write.assert_not_called()
                self.assert_unchanged(before)
                self.assertEqual(appearance, [1.25, 1.15])

    def test_rollbacks_are_independent_and_incomplete_recovery_is_reported(self):
        before = self.seed()
        appearance = []
        def appear(p):
            appearance.append(p["textScale"])
            if p["textScale"] == 1.15:
                raise RuntimeError("desktop gone")
        def write(name, text):
            if name == "idle.conf":
                raise OSError("disk full")
            real(name, text)
        real = s.atomic_write
        with patch.object(s, "apply_appearance", side_effect=appear), \
             patch.object(s, "atomic_write", side_effect=write):
            with self.assertRaises(RuntimeError) as caught:
                s.save({"textScale": 1.25, "cursorSize": 40, "lockMinutes": 4, "screenOffMinutes": 6})
        message = str(caught.exception)
        self.assertIn("disk full", message)
        self.assertIn("desktop gone", message)
        self.assertIn("incomplete", message)
        # The failing appearance rollback did not stop the file restores.
        self.assertEqual(appearance, [1.25, 1.15])
        self.assert_unchanged(before)

    def test_failed_file_restore_is_reported(self):
        before = self.seed()
        real = s.atomic_write
        calls = []
        def write(name, text):
            calls.append(name)
            if name == "idle.conf" or (name == "preferences.json" and calls.count(name) > 1):
                raise OSError("read-only " + name)
            real(name, text)
        with patch.object(s, "apply_appearance"), patch.object(s, "atomic_write", side_effect=write):
            with self.assertRaisesRegex(RuntimeError, "preferences.json"):
                s.save({"textScale": 1.25, "cursorSize": 40})
        # settings.lua was still restored even though preferences.json could not be.
        self.assertEqual((s.state_dir() / "settings.lua").read_text(), before["settings.lua"])

    def test_keep_display_failure_restores_monitor_choices(self):
        new = {"output": "Virtual-1", "mode": "1440x960@75.000", "scale": 1.25, "transform": 0}
        s.write_json("displays.json", {"Virtual-1": new | {"scale": 1}})
        before = (s.state_dir() / "displays.json").read_text()
        s.write_json("display-pending.json", {"token": "t", "new": new, "old": new | {"scale": 1}, "expires": 9e9})
        with patch.object(s, "verify_display"), patch.object(s, "atomic_write", self.failing_write("settings.lua")):
            with self.assertRaises(OSError):
                s.keep_display("t")
        self.assertEqual((s.state_dir() / "displays.json").read_text(), before)
        self.assertEqual(s.read_json("display-pending.json", {})["token"], "t")

    def test_disconnected_preview_output_still_clears_recovery_record(self):
        old = {"output": "HDMI-A-1", "mode": "1920x1080@60.000", "scale": 1, "transform": 0}
        s.write_json("display-pending.json", {"token": "t", "old": old, "new": old | {"scale": 2}, "expires": 0})
        with patch.object(s, "apply_display") as apply, patch.object(s, "monitors", return_value=[]):
            s.revert_display("t")
        # The output gets its saved settings.lua block on its next connection,
        # and Settings stays usable.
        apply.assert_not_called()
        self.assertEqual(s.read_json("display-pending.json", {}), {})

    def test_malformed_state_names_the_file_and_is_kept(self):
        s.atomic_write("preferences.json", "{broken")
        with self.assertRaisesRegex(ValueError, "preferences.json"):
            s.save({"showSeconds": True})
        self.assertEqual((s.state_dir() / "preferences.json").read_text(), "{broken")

    def test_reset_preserves_confirmed_monitor_and_account_state(self):
        displays = {"Virtual-1": {"output": "Virtual-1", "mode": "1440x960@75.000", "scale": 1, "transform": 0}}
        s.write_json("displays.json", displays)
        s.save({"showSeconds": True})
        s.save(s.defaults())
        self.assertIn('["output"]="Virtual-1"', (s.state_dir() / "settings.lua").read_text())
        self.assertEqual(s.read_json("preferences.json", None), {})
        self.assertEqual(s.read_json("displays.json", {}), displays)


unittest.main()
