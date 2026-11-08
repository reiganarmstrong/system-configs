"""Commands shared by the shell, idle daemon and compositor settings."""
import datetime
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time


def lua(value):
    """Encode validated data as Lua literals, never executable user input."""
    if isinstance(value, dict):
        return "{" + ",".join("[" + lua(k) + "]=" + lua(v) for k, v in value.items()) + "}"
    if isinstance(value, list):
        return "{" + ",".join(map(lua, value)) + "}"
    if value is None:
        return "nil"
    return json.dumps(value, ensure_ascii=False)


def command(action, *args):
    if action == "quit":
        return ["uwsm", "stop"]
    if action in ("power-on", "power-off"):
        on = action == "power-on"
        return ["hyprctl", "dispatch", "hl.dsp.dpms(" + lua({"action": "on" if on else "off"}) + ")"]
    if action == "focus-workspace":
        number = int(args[0])
        return ["hyprctl", "dispatch", "hl.dsp.focus(" + lua({"workspace": number}) + ")"]
    raise ValueError("Unknown compositor action")


def pick_color():
    time.sleep(0.3)  # Wait for the popup's closing fade.
    args = ["hyprpicker", "--format=hex"]
    result = subprocess.run(args, text=True, capture_output=True)
    colors = re.findall(r"#[0-9a-fA-F]{6}\b", result.stdout)
    if result.returncode == 0 and colors:
        subprocess.run(["wl-copy", "--", colors[-1]], check=True)


def screenshot(kind):
    directory = Path.home() / "pictures/screenshots"
    directory.mkdir(parents=True, exist_ok=True)
    target = directory / ("Screenshot " + datetime.datetime.now().strftime("%Y-%m-%d %H-%M-%S-%f") + ".png")
    args = ["grim"]
    if kind == "region":
        region = subprocess.run(["slurp"], text=True, capture_output=True)
        if region.returncode:
            return
        args += ["-g", region.stdout.strip()]
    elif kind == "window":
        window = json.loads(subprocess.check_output(["hyprctl", "-j", "activewindow"]))
        if not window:
            return
        args += ["-g", f'{window["at"][0]},{window["at"][1]} {window["size"][0]}x{window["size"][1]}']
    else:
        monitor = next(m for m in json.loads(subprocess.check_output(["hyprctl", "-j", "monitors"])) if m["focused"])
        args += ["-o", monitor["name"]]
    subprocess.run(args + [str(target)], check=True)
    with target.open("rb") as image:
        subprocess.run(["wl-copy", "--type", "image/png"], stdin=image, check=True)


def main():
    action, *args = sys.argv[1:]
    if action == "pick-color":
        pick_color()
    elif action == "screenshot":
        screenshot(args[0] if args else "region")
    else:
        subprocess.run(command(action, *args), check=True)


if __name__ == "__main__":
    main()
