"""Tests for roles/niri/files/jsonc-add-missing.py, the helper that adds
VSCodium's keyring and window-button settings without rewriting user files.

Run: python3 -I tests/test_jsonc_add_missing.py
"""

import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parent.parent / 'roles/niri/files/jsonc-add-missing.py'

# The argv.json VS Code-based editors write on first launch: comments only
# around the members, and a trailing comma.
DEFAULT_ARGV = '''// This configuration file allows you to pass permanent command line arguments to VS Code.
// Only a subset of arguments is currently supported to reduce the likelihood of breaking
// the installation.
//
// PLEASE DO NOT CHANGE WITHOUT UNDERSTANDING THE IMPACT
{
	// Use software rendering instead of hardware accelerated rendering.
	// "disable-hardware-acceleration": true,

	// Allows to disable crash reporting.
	"enable-crash-reporter": false, /* keep { braces } "quoted" in comments */
	"url": "https://example.com/a//b",
}
'''


def run(path, *pairs):
    result = subprocess.run(
        [sys.executable, '-I', str(SCRIPT), str(path), *pairs],
        check=True, capture_output=True, text=True,
    )
    return json.loads(result.stdout)


def strip_comments(text):
    import importlib.util
    spec = importlib.util.spec_from_file_location('helper', SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return json.loads(module.remove_trailing_commas(module.strip_jsonc(text)))


class AddMissingTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.path = pathlib.Path(self.directory.name) / 'argv.json'

    def tearDown(self):
        self.directory.cleanup()

    def test_creates_missing_file(self):
        result = run(self.path, 'password-store="gnome-libsecret"')
        self.assertEqual(result, {'changed': True, 'added': ['password-store'], 'error': None})
        self.assertEqual(json.loads(self.path.read_text()), {'password-store': 'gnome-libsecret'})

    def test_adds_to_commented_file_and_keeps_everything_else(self):
        self.path.write_text(DEFAULT_ARGV)
        os.chmod(self.path, 0o600)
        result = run(self.path, 'password-store="gnome-libsecret"')
        self.assertTrue(result['changed'])
        text = self.path.read_text()
        # Every original line survives, in order.
        self.assertIn(DEFAULT_ARGV.split('{', 1)[1], text)
        self.assertTrue(text.startswith(DEFAULT_ARGV.split('{', 1)[0]))
        self.assertEqual(strip_comments(text), {
            'password-store': 'gnome-libsecret',
            'enable-crash-reporter': False,
            'url': 'https://example.com/a//b',
        })
        self.assertEqual(os.stat(self.path).st_mode & 0o777, 0o600)

    def test_second_run_changes_nothing(self):
        self.path.write_text(DEFAULT_ARGV)
        run(self.path, 'password-store="gnome-libsecret"')
        before = self.path.read_text()
        result = run(self.path, 'password-store="gnome-libsecret"')
        self.assertEqual(result, {'changed': False, 'added': [], 'error': None})
        self.assertEqual(self.path.read_text(), before)

    def test_never_overrides_the_users_value(self):
        self.path.write_text('{ "password-store": "basic" }\n')
        result = run(self.path, 'password-store="gnome-libsecret"')
        self.assertFalse(result['changed'])
        self.assertEqual(json.loads(self.path.read_text()), {'password-store': 'basic'})

    def test_empty_object_stays_strict_json(self):
        self.path.write_text('// note\n{}\n')
        run(self.path, 'window.controlsStyle="hidden"')
        self.assertEqual(strip_comments(self.path.read_text()), {'window.controlsStyle': 'hidden'})
        self.assertTrue(self.path.read_text().startswith('// note\n'))

    def test_unparseable_file_is_reported_and_left_alone(self):
        broken = '{ "a": 1 /* unterminated\n'
        self.path.write_text(broken)
        result = run(self.path, 'password-store="gnome-libsecret"')
        self.assertFalse(result['changed'])
        self.assertIsNotNone(result['error'])
        self.assertEqual(self.path.read_text(), broken)

    def test_non_object_is_reported_and_left_alone(self):
        self.path.write_text('[1, 2]\n')
        result = run(self.path, 'password-store="gnome-libsecret"')
        self.assertIsNotNone(result['error'])
        self.assertEqual(self.path.read_text(), '[1, 2]\n')


if __name__ == '__main__':
    unittest.main()
