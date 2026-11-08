"""Exercise native icon extraction, malformed containers and atomic updates."""

import os
from pathlib import Path
import runpy
import struct
import tempfile
import unittest
import zlib


TOOL = runpy.run_path(str(Path(__file__).parents[1] / "roles/niri/files/icns-to-png.py"))


def png(size):
    def chunk(tag, payload):
        return struct.pack(">I", len(payload)) + tag + payload + struct.pack(">I", zlib.crc32(tag + payload))
    rows = (b"\0" + b"\xff\xff\xff" * size) * size
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(rows))
        + chunk(b"IEND", b"")
    )


def icns(*payloads):
    body = b"".join(b"ic10" + struct.pack(">I", 8 + len(p)) + p for p in payloads)
    return b"icns" + struct.pack(">I", 8 + len(body)) + body


class IconExtractionTests(unittest.TestCase):
    def test_largest_native_png_is_preserved_byte_for_byte(self):
        small, large = png(2), png(4)
        self.assertEqual(TOOL["extract_png"](icns(small, large, small)), large)

    def test_unknown_non_png_records_are_ignored(self):
        image = png(2)
        self.assertEqual(TOOL["extract_png"](icns(b"unrelated metadata", image)), image)

    def test_malformed_or_unsupported_containers_fail_cleanly(self):
        cases = [
            b"", b"not an icon", icns(png(2))[:-1], icns(b"not a PNG"),
            b"icns" + struct.pack(">I", 16) + b"ic10" + struct.pack(">I", 0),
            b"icns" + struct.pack(">I", 16) + b"ic10" + struct.pack(">I", 1000),
            b"icns" + struct.pack(">I", 11) + b"bad",
        ]
        for data in cases:
            with self.subTest(data=data[:16]), self.assertRaises(ValueError):
                TOOL["extract_png"](data)

    def test_unchanged_extraction_does_not_rewrite_the_png(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, target = root / "icon.icns", root / "icon.png"
            source.write_bytes(icns(png(2)))
            self.assertTrue(TOOL["install"](source, target))
            os.utime(target, ns=(1000000000, 1000000000))
            self.assertFalse(TOOL["install"](source, target))
            self.assertEqual(target.stat().st_mtime_ns, 1000000000)
            self.assertEqual(target.stat().st_mode & 0o777, 0o644)
            self.assertEqual(target.read_bytes(), png(2))

    def test_bad_source_leaves_an_existing_icon_untouched(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, target = root / "icon.icns", root / "icon.png"
            good = icns(png(2))
            # A malformed trailing record must fail even after a valid PNG.
            source.write_bytes(good[:4] + struct.pack(">I", len(good) + 3) + good[8:] + b"bad")
            target.write_bytes(b"existing icon")
            with self.assertRaises(ValueError):
                TOOL["install"](source, target)
            self.assertEqual(target.read_bytes(), b"existing icon")
            self.assertEqual(sorted(p.name for p in root.iterdir()), ["icon.icns", "icon.png"])


if __name__ == "__main__":
    unittest.main()
