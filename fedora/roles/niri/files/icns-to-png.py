#!/usr/bin/env python3
"""Extract the largest embedded PNG without resampling or recoloring it."""

import argparse
import os
from pathlib import Path
import struct
import tempfile


def extract_png(data: bytes) -> bytes:
    if len(data) < 8 or data[:4] != b"icns":
        raise ValueError("Not an ICNS file")
    if struct.unpack_from(">I", data, 4)[0] != len(data):
        raise ValueError("ICNS file length does not match its header")
    candidates = []
    offset = 8
    while offset < len(data):
        if len(data) - offset < 8:
            raise ValueError("Truncated ICNS entry header")
        length = struct.unpack_from(">I", data, offset + 4)[0]
        if length < 8 or length > len(data) - offset:
            raise ValueError("Invalid ICNS entry length")
        payload = data[offset + 8:offset + length]
        is_png = (
            len(payload) >= 24
            and payload[:8] == b"\x89PNG\r\n\x1a\n"
            and payload[12:16] == b"IHDR"
        )
        if is_png:
            width, height = struct.unpack_from(">II", payload, 16)
            if 0 < width == height <= 4096:
                candidates.append((width, payload))
        offset += length
    if not candidates:
        raise ValueError("ICNS file contains no supported square PNG")
    return max(candidates, key=lambda entry: entry[0])[1]


def install(source: Path, destination: Path) -> bool:
    data = extract_png(source.read_bytes())
    if destination.is_file() and destination.read_bytes() == data:
        return False
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=destination.parent, delete=False) as handle:
            temporary = Path(handle.name)
            handle.write(data)
            os.fchmod(handle.fileno(), 0o644)
        os.replace(temporary, destination)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    return True


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    arguments = parser.parse_args()
    try:
        changed = install(arguments.source, arguments.destination)
    except (OSError, ValueError) as error:
        parser.exit(1, f"{error}\n")
    print("updated" if changed else "unchanged")


if __name__ == "__main__":
    main()
