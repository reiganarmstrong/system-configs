"""Small JSON interface to cliphist. Clipboard contents never enter a shell.

cliphist owns storage, deduplication and byte-exact recall. This adapter adds
serialized operations, private thumbnails and a persistent capture-pause flag.
"""
import contextlib
import fcntl
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys

MAX_BYTES = 5_000_000


def directory():
    base = os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))
    return Path(base) / "system-configs/clipboard"


@contextlib.contextmanager
def locked():
    os.umask(0o077)
    root = directory()
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (root / ".lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def cliphist(action, *args, data=None):
    command = ["cliphist", "-db-path", str(directory() / "history.db"),
               "-max-items", "200", "-max-dedupe-search", "200", "-preview-width", "180", action, *args]
    result = subprocess.run(command, input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=8)
    if result.returncode:
        raise RuntimeError("Clipboard history could not be read or updated")
    return result.stdout


def valid_id(value):
    if not re.fullmatch(r"[0-9]{1,20}", value):
        raise ValueError("Invalid clipboard item")
    return value


def mime_type(data):
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if data.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if data.startswith((b"GIF87a", b"GIF89a")):
        return "image/gif"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    if data.startswith(b"BM"):
        return "image/bmp"
    if data.startswith((b"II*\0", b"MM\0*")):
        return "image/tiff"
    try:
        data.decode("utf-8")
        if b"\0" not in data:
            return "text/plain;charset=utf-8"
    except UnicodeDecodeError:
        pass
    return "application/octet-stream"


def thumbnail(item_id):
    path = directory() / "thumbnails" / (item_id + ".png")
    if not path.exists():
        from PIL import Image
        try:
            with Image.open(io.BytesIO(cliphist("decode", item_id))) as image:
                if image.width * image.height > 16_000_000:
                    return ""
                image.thumbnail((96, 72))
                image = image.convert("RGBA")
                path.parent.mkdir(mode=0o700, exist_ok=True)
                image.save(path, format="PNG")
        except (OSError, ValueError, Image.DecompressionBombError):
            return ""
    return path.as_uri()


def snapshot():
    items = []
    if (directory() / "history.db").exists():
        for line in cliphist("list").decode("utf-8", errors="replace").splitlines():
            item_id, separator, preview = line.partition("\t")
            if not separator or not item_id.isdecimal():
                continue
            image = bool(re.fullmatch(r"\[\[ binary data .+ (png|jpeg|gif|bmp|tiff) \d+x\d+ \]\]", preview))
            items.append({"id": item_id, "preview": preview, "kind": "image" if image else "text", "thumbnail": ""})
        # Decode only a small number of images, then reuse their tiny thumbnails.
        images = [item for item in items if item["kind"] == "image"]
        for item in images[:12]:
            item["thumbnail"] = thumbnail(item["id"])
        cache = directory() / "thumbnails"
        live = {item["id"] + ".png" for item in items}
        if cache.exists():
            for path in cache.glob("*.png"):
                if path.name not in live:
                    path.unlink()
    return {"items": items, "paused": (directory() / "paused").exists()}


def perform(action, value=None, payload=None):
    if action == "store":
        if (directory() / "paused").exists():
            return None
        # cliphist also honours sensitive/clear hints from wl-clipboard.
        if payload is not None and len(payload) <= MAX_BYTES:
            cliphist("store", data=payload)
        return None
    if action == "list":
        return snapshot()
    if action == "copy":
        data = cliphist("decode", valid_id(value))
        mime = mime_type(data)
        result = subprocess.run(["wl-copy", "--type", mime], input=data,
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=8)
        if result.returncode:
            raise RuntimeError("Could not copy this item. Try again.")
        return {"copied": True}
    if action == "delete":
        item_id = valid_id(value)
        cliphist("delete", data=(item_id + "\n").encode())
        (directory() / "thumbnails" / (item_id + ".png")).unlink(missing_ok=True)
        return snapshot()
    if action == "clear":
        if (directory() / "history.db").exists():
            cliphist("wipe")
        cache = directory() / "thumbnails"
        if cache.exists():
            for path in cache.glob("*.png"):
                path.unlink()
        return snapshot()
    if action == "pause":
        if value not in ("true", "false"):
            raise ValueError("Invalid capture state")
        flag = directory() / "paused"
        if value == "true":
            flag.touch(mode=0o600)
        else:
            flag.unlink(missing_ok=True)
        return snapshot()
    raise ValueError("Unknown clipboard action")


def main():
    action = sys.argv[1]
    payload = sys.stdin.buffer.read(MAX_BYTES + 1) if action == "store" else None
    with locked():
        result = perform(action, sys.argv[2] if len(sys.argv) > 2 else None, payload)
    if result is not None:
        print(json.dumps(result))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        if len(sys.argv) > 1 and sys.argv[1] == "store":
            print("Clipboard capture failed", file=sys.stderr)
        else:
            print(json.dumps({"error": str(error)}))
        sys.exit(1)
