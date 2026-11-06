"""Real cliphist contract checks using a private temporary history database."""
import importlib.util
import io
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from PIL import Image

spec = importlib.util.spec_from_file_location("history", sys.argv.pop(1))
history = importlib.util.module_from_spec(spec)
spec.loader.exec_module(history)


class ClipboardHistoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.env = patch.dict(os.environ, {"XDG_STATE_HOME": self.temp.name})
        self.env.start()
        os.environ.pop("CLIPBOARD_STATE", None)
        os.umask(0o077)
        history.directory().mkdir(parents=True, mode=0o700)

    def tearDown(self):
        self.env.stop()
        self.temp.cleanup()

    def store(self, value):
        history.perform("store", payload=value)
        return history.snapshot()["items"]

    def test_first_run_is_empty(self):
        self.assertEqual(history.snapshot(), {"items": [], "paused": False})

    def test_exact_text_round_trip_dedup_and_delete(self):
        value = "  café\n\tquoted `code` $(literal) <b>text</b>\n\n".encode()
        item = self.store(value)[0]
        self.assertEqual(history.cliphist("decode", item["id"]), value)
        self.assertEqual(item["kind"], "text")
        duplicate = self.store(value)
        self.assertEqual(len(duplicate), 1)
        self.assertEqual(history.cliphist("decode", duplicate[0]["id"]), value)
        self.assertEqual(history.perform("delete", duplicate[0]["id"])["items"], [])

    def test_image_round_trip_thumbnail_and_clear(self):
        buffer = io.BytesIO()
        Image.new("RGB", (160, 120), "#2f7cf6").save(buffer, format="PNG")
        value = buffer.getvalue()
        item = self.store(value)[0]
        self.assertEqual(item["kind"], "image")
        self.assertEqual(history.cliphist("decode", item["id"]), value)
        self.assertEqual(history.mime_type(value), "image/png")
        thumb = history.directory() / "thumbnails" / (item["id"] + ".png")
        with Image.open(thumb) as image:
            self.assertEqual(image.size, (96, 72))
        self.assertEqual(history.perform("clear")["items"], [])
        self.assertFalse(thumb.exists())

    def test_pause_survives_reopen_and_does_not_capture(self):
        self.assertTrue(history.perform("pause", "true")["paused"])
        self.store(b"not captured")
        self.assertEqual(history.snapshot()["items"], [])
        self.assertTrue(history.snapshot()["paused"])
        self.assertFalse(history.perform("pause", "false")["paused"])
        self.assertEqual(len(self.store(b"captured after resume")), 1)

    def test_sensitive_hint_is_respected(self):
        with patch.dict(os.environ, {"CLIPBOARD_STATE": "sensitive"}):
            self.store(b"marked sensitive")
        self.assertEqual(history.snapshot()["items"], [])

    def test_oversized_selection_is_skipped(self):
        self.store(b"x" * (history.MAX_BYTES + 1))
        self.assertEqual(history.snapshot()["items"], [])

    def test_item_ids_cannot_be_commands_or_paths(self):
        self.store(b"valid")
        for invalid in ["../history.db", "1; echo wrong", "-1", "$(id)"]:
            with self.assertRaises(ValueError):
                history.perform("delete", invalid)
        self.assertEqual(len(history.snapshot()["items"]), 1)

    def test_private_permissions(self):
        self.store(b"permission check")
        self.assertEqual((history.directory() / "history.db").stat().st_mode & 0o777, 0o600)
        self.assertEqual(history.directory().stat().st_mode & 0o777, 0o700)


unittest.main()
