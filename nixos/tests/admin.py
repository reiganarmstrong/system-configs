"""Exercise the same typed Settings interface used by the GUI; no real changes."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

path = Path(sys.argv.pop(1))
sys.path.insert(0, str(path.parent))
spec = importlib.util.spec_from_file_location("desktop_admin", path)
a = importlib.util.module_from_spec(spec)
spec.loader.exec_module(a)


class AdminTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.env = patch.dict(os.environ, {"XDG_STATE_HOME": self.tmp.name, "XDG_RUNTIME_DIR": self.tmp.name,
                                         "HYPRLAND_INSTANCE_SIGNATURE": "test_session", "DESKTOP_ADMIN_CONFIG": "{}"})
        self.env.start()

    def tearDown(self):
        self.env.stop()
        self.tmp.cleanup()

    def test_unknown_and_extra_fields_never_execute(self):
        with patch.object(a, "execute") as execute:
            for action, data in [("command", {"argv":["bad"]}), ("snapshot", {"section":"apps", "command":"bad"}),
                                 ("update", {"kind":"system", "unit":"bad"}), ("tailscale", {"enabled":"yes"})]:
                with self.subTest(action=action), self.assertRaises(ValueError): a.perform(action, data)
            execute.assert_not_called()

    def test_application_id_cannot_be_used_as_command_or_unit(self):
        with patch.object(a, "execute") as execute:
            for value in ["org.test.App;touch bad", "--help", "../../etc", "org.test.App\n", "org.test.App/other"]:
                with self.subTest(value=value), self.assertRaises(ValueError): a.perform("app-install", {"id":value})
            execute.assert_not_called()

    def test_system_apps_cannot_be_removed(self):
        with patch.object(a, "flatpaks", return_value=[{"id":"org.test.App", "scope":"system"}]), patch.object(a, "execute") as execute:
            with self.assertRaises(ValueError): a.perform("app-remove", {"id":"org.test.App"})
            execute.assert_not_called()

    def test_install_uses_fixed_user_job(self):
        with patch.object(a, "execute") as execute:
            a.perform("app-install", {"id":"org.test.App"})
            execute.assert_called_once_with(["systemctl","--user","start","--no-block","desktop-flatpak-install@org.test.App.service"])

    def test_mutable_startup_registry_and_stale_entry_removal(self):
        with patch.object(a, "app_info") as installed:
            a.perform("startup", {"id":"test.desktop", "enabled":True})
            self.assertEqual(a.startup_ids(), ["test"])
            a.perform("startup", {"id":"test", "enabled":True})
            self.assertEqual(a.startup_ids(), ["test"])
            installed.reset_mock()
            a.perform("startup", {"id":"test", "enabled":False})
            installed.assert_not_called()
            self.assertEqual(a.startup_ids(), [])

    def test_startup_executes_once_per_compositor_session(self):
        a.write_json("startup.json", ["test"])
        with patch.object(a, "app_info"), patch.object(a, "apply_appearance"), patch.object(a, "execute") as execute:
            self.assertEqual(a.startup_run()["started"], 1)
            self.assertEqual(a.startup_run()["started"], 0)
            execute.assert_called_once_with(["qs","ipc","call","launcher","launch","test"],timeout=5)

    def test_corrupt_startup_state_is_preserved(self):
        a.write_json("startup.json", {"unexpected":True})
        with patch.object(a, "app_info"), self.assertRaises(ValueError): a.perform("startup", {"id":"test", "enabled":False})
        self.assertEqual(a.read_json("startup.json", {}), {"unexpected":True})

    def test_default_handlers_use_registered_app_info(self):
        app = Mock()
        app.get_id.return_value = "test.desktop"
        app.set_as_default_for_type.return_value = True
        with patch.object(a, "app_info", return_value=app), \
             patch.object(a, "handlers", return_value=[{"id": "test.desktop", "name": "Test", "visible": True}]):
            a.perform("default-app", {"kind":"browser", "id":"test.desktop"})
        self.assertEqual([call.args[0] for call in app.set_as_default_for_type.call_args_list], a.MIMES["browser"])

    def test_default_app_must_declare_the_type(self):
        mixer = Mock()
        mixer.get_id.return_value = "pavucontrol.desktop"
        mixer.get_display_name.return_value = "Volume Control"
        with patch.object(a, "app_info", return_value=mixer), \
             patch.object(a, "handlers", return_value=[{"id": "mpv.desktop", "name": "mpv", "visible": True}]):
            with self.assertRaisesRegex(ValueError, "Volume Control cannot open"):
                a.perform("default-app", {"kind": "audio", "id": "pavucontrol.desktop"})
        mixer.set_as_default_for_type.assert_not_called()

    def test_text_editor_category_is_the_only_category_fallback(self):
        editor = {"id": "codium.desktop", "name": "VSCodium", "visible": True}
        with patch.object(a, "handlers", return_value=[]), patch.object(a, "text_editors", return_value=[editor]):
            self.assertEqual(a.candidates("text"), [editor])
            self.assertEqual(a.candidates("audio"), [])

    def test_default_candidates_come_from_mime_support_and_keep_current(self):
        supported = {"x-scheme-handler/mailto": [{"id": "mail.desktop", "name": "Mail", "visible": True}],
                     "audio/mpeg": [{"id": "hidden.desktop", "name": "Hidden player", "visible": False}]}
        current = {"x-scheme-handler/mailto": {"id": "zen.desktop", "name": "Zen"},
                   "audio/mpeg": {"id": "hidden.desktop", "name": "Hidden player"}}
        with patch.object(a, "handlers", side_effect=lambda m: supported.get(m, [])), patch.object(a, "text_editors", return_value=[]), \
             patch.object(a, "default_handler", side_effect=lambda m: current.get(m)):
            result = a.default_apps()
        self.assertEqual(result["mail"]["current"], "zen.desktop")
        self.assertEqual([x["id"] for x in result["mail"]["apps"]], ["mail.desktop", "zen.desktop"])
        self.assertEqual(result["audio"]["apps"], [{"id": "hidden.desktop", "name": "Hidden player"}])
        self.assertEqual(result["video"], {"current": "", "apps": []})

    def test_failed_jobs_are_attributed_and_bounded(self):
        listing = json.dumps([{"unit": "desktop-flatpak-remove@org.test.App.service"},
                              {"unit": "desktop-flatpak-update.service"}, {"unit": "other.service"}])
        def response(argv, **kwargs):
            if argv[2] == "list-units": return listing
            if argv[0] == "journalctl":
                self.assertEqual(argv[2:4], ["_SYSTEMD_USER_UNIT=desktop-flatpak-remove@org.test.App.service", "_SYSTEMD_INVOCATION_ID=abc"])
                return "x" * 5000
            return "ActiveState=failed\nResult=exit-code\nInvocationID=abc" if "remove@" in argv[3] else "ActiveState=inactive\nResult=success"
        with patch.object(a, "execute", side_effect=response):
            result = a.jobs()
        self.assertEqual([(j["operation"], j["app"]) for j in result], [("remove", "org.test.App"), ("update", "")])
        self.assertEqual(result[0]["log"], "x" * 600)
        self.assertNotIn("log", result[1])

    def test_failed_job_log_falls_back_to_systemd_lines(self):
        def response(argv, **kwargs):
            if argv[2] == "list-units": return json.dumps([{"unit": "desktop-flatpak-install@org.test.App.service"}])
            if argv[0] == "journalctl": return "" if argv[2].startswith("_SYSTEMD_USER_UNIT=") else "Failed with result 'timeout'."
            return "ActiveState=failed"
        with patch.object(a, "execute", side_effect=response):
            self.assertEqual(a.jobs()[0]["log"], "Failed with result 'timeout'.")

    def test_dismiss_only_resets_listed_failed_jobs(self):
        failed = [{"unit": "desktop-flatpak-install@org.test.App.service", "ActiveState": "failed"}]
        with patch.object(a, "jobs", return_value=failed), patch.object(a, "execute") as execute:
            for unit in ["sshd.service", "desktop-flatpak-install@org.other.App.service", "desktop-flatpak-install@x;y.service"]:
                with self.subTest(unit=unit), self.assertRaises(ValueError):
                    a.perform("app-job-dismiss", {"unit": unit})
            execute.assert_not_called()
            a.perform("app-job-dismiss", {"unit": failed[0]["unit"]})
            execute.assert_called_once_with(["systemctl", "--user", "reset-failed", failed[0]["unit"]])

    def test_cancelled_authentication_is_distinguished_from_denial(self):
        def completed(code, stderr):
            return subprocess.CompletedProcess([], code, "", stderr)
        with patch.object(a.subprocess, "run", return_value=completed(126, "Error executing command as another user: Request dismissed")):
            with self.assertRaises(a.AuthenticationCancelled): a.execute([a.PKEXEC, a.LPADMIN, "-x", "Office"])
        with patch.object(a.subprocess, "run", return_value=completed(1, "Failed to set time zone: Access denied")):
            with self.assertRaises(a.AuthenticationCancelled): a.execute(["timedatectl", "set-timezone", "UTC"])
        with patch.object(a.subprocess, "run", return_value=completed(127, "Error executing command as another user: Not authorized")):
            with self.assertRaisesRegex(RuntimeError, "Not authorized") as caught: a.execute([a.PKEXEC, a.LPADMIN, "-x", "Office"])
            self.assertNotIsInstance(caught.exception, a.AuthenticationCancelled)

    def test_tailscale_reconnects_with_bare_up(self):
        with patch.object(a, "snapshot", return_value={"state": "Stopped"}), patch.object(a, "execute") as execute:
            a.perform("tailscale", {"enabled": True})
            execute.assert_called_once_with(["tailscale", "up"], timeout=15)
        with patch.object(a, "snapshot", return_value={"state": "Stopped"}), \
             patch.object(a, "execute", side_effect=subprocess.TimeoutExpired(["tailscale"], 15)):
            self.assertEqual(a.perform("tailscale", {"enabled": True})["notice"], "Tailscale is still connecting.")

    def test_failed_requests_report_sections_to_refresh(self):
        result = subprocess.run([sys.executable, str(path), "startup"], input=json.dumps({"id": "bad;id", "enabled": True}),
                                text=True, capture_output=True, env=os.environ | {"PYTHONPATH": str(path.parent)})
        self.assertEqual(result.returncode, 1)
        self.assertEqual(json.loads(result.stdout), {"error": "Invalid application", "cancelled": False, "refresh": ["apps"]})

    def test_system_update_is_not_available_in_vm(self):
        with patch.object(a, "execute") as execute, self.assertRaises(ValueError): a.perform("update", {"kind":"system"})
        execute.assert_not_called()

    def test_system_update_uses_standard_auth_and_fixed_unit(self):
        with patch.dict(os.environ, {"DESKTOP_ADMIN_CONFIG":'{"updates":true}'}), patch.object(a, "execute") as execute:
            a.perform("update", {"kind":"system"})
            execute.assert_called_once_with([a.PKEXEC,a.SYSTEMCTL,"start","--no-block","nixos-upgrade.service"],timeout=120)

    def test_system_and_home_storage_are_protected(self):
        data = {"volumes":[{"device":"/dev/vda1","protected":True}], "drives":[]}
        with patch.object(a, "block_devices", return_value=data), patch.object(a, "execute") as execute:
            for op in ["mount","unmount"]:
                with self.assertRaises(ValueError): a.storage_operation(op, "/dev/vda1")
            with self.assertRaises(ValueError): a.storage_operation("unmount", "/dev/not-listed")
            execute.assert_not_called()

    def test_removable_storage_uses_udisks_without_shell(self):
        data = {"volumes":[{"device":"/dev/sdb1","protected":False,"filesystem":"vfat"}],"drives":[]}
        with patch.object(a, "block_devices", return_value=data), patch.object(a, "execute") as execute:
            a.storage_operation("mount", "/dev/sdb1")
            execute.assert_called_once_with(["udisksctl","mount","--block-device","/dev/sdb1"],timeout=60)

    def test_lsblk_null_models_and_home_ancestor_protection(self):
        device = {"name":"/dev/vda","type":"disk","size":1000,"model":None,"children":[
            {"name":"/dev/vda1","type":"part","size":1000,"model":None,"fstype":"ext4","mountpoints":["/"]}]}
        with patch.object(a, "execute", return_value=json.dumps({"blockdevices":[device]})):
            result = a.block_devices()
        self.assertTrue(result["volumes"][0]["protected"])
        self.assertTrue(result["drives"][0]["protected"])

    def test_boot_and_other_system_volumes_are_protected(self):
        for mount in ["/boot", "/boot/efi", "/efi", "/nix", "/var", "/home"]:
            with self.subTest(mount=mount):
                device = {"name":"/dev/test", "type":"part", "fstype":"ext4", "mountpoints":[mount]}
                with patch.object(a, "execute", return_value=json.dumps({"blockdevices":[device]})):
                    self.assertTrue(a.block_devices()["volumes"][0]["protected"])

    def test_printer_rejects_credentials_and_non_ipp_addresses(self):
        with patch.object(a, "execute") as execute:
            for uri in ["file:///etc/passwd", "ipp://user:pass@printer/ipp", "ipp://", "ipp://printer/\n"]:
                with self.subTest(uri=uri), self.assertRaises(ValueError): a.printer_operation("add", {"name":"Office", "uri":uri})
            execute.assert_not_called()

    def test_printer_creation_uses_fixed_authorized_command(self):
        with patch.object(a, "execute") as execute:
            a.printer_operation("add", {"name":"Office", "uri":"ipps://printer.local/ipp/print"})
            execute.assert_called_once_with([a.PKEXEC,a.LPADMIN,"-p","Office","-v","ipps://printer.local/ipp/print","-m","everywhere","-E"],timeout=120)

    def test_only_existing_owned_jobs_can_be_cancelled(self):
        with patch.object(a, "printers", return_value={"jobs":["Office-7"]}), patch.object(a, "execute") as execute:
            with self.assertRaises(ValueError): a.printer_operation("cancel", {"job":"--all"})
            a.printer_operation("cancel", {"job":"Office-7"})
            execute.assert_called_once_with(["cancel","Office-7"])

    def test_time_status_reads_each_systemd_property(self):
        def response(argv, **kwargs):
            if argv[1] == "list-timezones": return "UTC\nAmerica/New_York"
            # timedatectl accepts repeated property flags, unlike systemctl's comma lists.
            self.assertEqual(argv[2:], ["--property=Timezone", "--property=NTP", "--property=NTPSynchronized", "--property=LocalRTC"])
            return "Timezone=America/New_York\nNTP=yes\nNTPSynchronized=yes"
        with patch.object(a, "execute", side_effect=response):
            result = a.time_status()
        self.assertEqual(result["timezone"], "America/New_York")
        self.assertTrue(result["networkTime"])
        self.assertTrue(result["synchronized"])

    def test_timezone_requires_installed_database_entry(self):
        with patch.object(a, "execute", return_value="UTC\nEurope/London") as execute:
            with self.assertRaises(ValueError): a.perform("timezone", {"zone":"../../etc"})
            a.perform("timezone", {"zone":"Europe/London"})
            self.assertEqual(execute.call_args.args[0], ["timedatectl","set-timezone","Europe/London"])

    def test_vpn_unknown_profile_cannot_control_other_connections(self):
        with patch.object(a, "network_profiles", return_value=[]), patch.object(a, "execute") as execute:
            with self.assertRaises(ValueError): a.perform("network-profile", {"uuid":"00000000-0000-0000-0000-000000000000", "enabled":True})
            execute.assert_not_called()

    def test_permission_display_does_not_read_credentials(self):
        raw = "[Context]\nshared=network;ipc;\nfilesystems=xdg-download;\ndevices=dri;\n"
        with patch.object(a, "execute", return_value=raw) as execute:
            result = a.app_permissions("org.test.App", "system")
            self.assertTrue(result["network"])
            self.assertEqual(result["filesystems"], ["xdg-download"])
            execute.assert_called_once_with(["flatpak","info","--system","--show-permissions","org.test.App"])


if __name__ == "__main__": unittest.main()
