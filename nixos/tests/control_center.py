"""Run inside the graphical session: python3 nixos/tests/control_center.py.

Exercises the real Quickshell popup lifecycle through its public IPC interface.
Requires Reduce Motion off so a visible closing frame can be checked.
"""
import json
import subprocess
import time
import unittest


def call(*args):
    return subprocess.check_output(["qs", "ipc", "call", "control", *args], text=True, timeout=5).strip()


def state():
    return json.loads(call("status"))


class ControlCenterLifecycle(unittest.TestCase):
    def tearDown(self):
        if state()["open"]:
            call("toggle")
        time.sleep(0.22)

    def test_submenu_survives_close_animation_and_reopen_starts_at_home(self):
        for page in ["network", "bluetooth", "sound"]:
            with self.subTest(page=page):
                call("openPage", page)
                time.sleep(0.3)
                self.assertEqual(state()["page"], page)
                call("toggle")
                frames = []
                deadline = time.monotonic() + 0.5
                while time.monotonic() < deadline:
                    frame = state()
                    if not frame["visible"]:
                        break
                    frames.append(frame)
                    time.sleep(0.008)
                self.assertTrue(frames, "No fade frames observed; turn Reduce Motion off")
                for frame in frames:
                    self.assertFalse(frame["open"])
                    self.assertEqual(frame["page"], page, "Home grid replaced submenu during close")
                    self.assertEqual(frame["shownPage"], page, "Submenu unloaded before fade finished")
                time.sleep(0.03)
                self.assertFalse(state()["visible"])
                self.assertEqual(state()["shownPage"], "", "Closed submenu should release scanning and device tracking")
                call("toggle")
                self.assertEqual(state()["page"], "", "Reopening should start on home grid")
                call("toggle")
                time.sleep(0.23)

    def test_quick_reopen_does_not_run_stale_hidden_cleanup(self):
        call("openPage", "sound")
        time.sleep(0.3)
        call("toggle")
        time.sleep(0.025)
        call("openPage", "network")
        time.sleep(0.3)
        current = state()
        self.assertTrue(current["open"])
        self.assertEqual(current["page"], "network")
        self.assertEqual(current["shownPage"], "network")


if __name__ == "__main__":
    unittest.main()
