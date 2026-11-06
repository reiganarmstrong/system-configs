"""Run in the unlocked desktop session. Reads metadata, never account/clipboard contents.

Checks every Settings page and scanner ownership shared with Control Center.
Requires a Wi-Fi adapter for the scanner assertion; the VM supplies a test radio.
"""
import json
import subprocess
import time
import unittest

PAGES = "appearance notifications accessibility privacy accounts display sound input power printers network bluetooth apps defaults startup storage time updates system".split()


def call(target, *args):
    return subprocess.check_output(["qs", "ipc", "call", target, *args], text=True, timeout=5).strip()


def state():
    return json.loads(call("settings", "status"))


def wait_for(predicate, timeout=20):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = state()
        if predicate(value):
            return value
        time.sleep(0.05)
    raise AssertionError("Settings did not reach the expected state")


class SettingsUI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if json.loads(call("session", "status"))["locked"]:
            raise unittest.SkipTest("Unlock the desktop first")

    def tearDown(self):
        if state()["open"]:
            call("settings", "toggle")
        if json.loads(call("control", "status"))["open"]:
            call("control", "toggle")
        time.sleep(0.25)

    def test_every_page_loads_and_helpers_finish(self):
        for page in PAGES:
            with self.subTest(page=page):
                call("settings", "open", page)
                result = wait_for(lambda s: s["page"] == page and s["pageReady"] and not s["adminBusy"])
                self.assertTrue(result["ready"])
                self.assertEqual(result["adminError"], "")
                self.assertEqual(result["error"], "")
        self.assertTrue(set(["apps", "defaults", "storage", "time", "printers", "accounts", "updates", "network"]).issubset(result["sections"]))

    def test_wifi_scanning_survives_other_consumer_closing(self):
        call("settings", "open", "network")
        result = wait_for(lambda s: s["pageReady"] and not s["adminBusy"])
        if not result["wifiScanning"]:
            self.skipTest("An enabled Wi-Fi adapter is required")
        call("control", "openPage", "network")
        time.sleep(0.3)
        call("settings", "toggle")
        wait_for(lambda s: not s["pageReady"])
        self.assertTrue(state()["wifiScanning"])
        call("settings", "open", "network")
        call("control", "toggle")
        time.sleep(0.3)
        self.assertTrue(state()["wifiScanning"])
        call("settings", "toggle")
        wait_for(lambda s: not s["pageReady"] and not s["wifiScanning"])


if __name__ == "__main__":
    unittest.main()
