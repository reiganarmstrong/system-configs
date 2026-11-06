"""Validated, per-user desktop preferences and reversible monitor changes.

Nix owns the defaults. Only explicit user overrides go in the state directory.
No commands are run through a shell; generated Lua uses JSON string escaping.
"""
import contextlib
import fcntl
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import time
import uuid

# key: (default, type, minimum, maximum) or (default, allowed values)
SCHEMA = {
    "wallpaper": ("", str, None, None),
    "panelOpacity": (0.55, float, 0.35, 1.0),
    "reduceMotion": (False, bool, None, None),
    "clock24h": (False, bool, None, None),
    "showSeconds": (False, bool, None, None),
    "showBatteryPercent": (True, bool, None, None),
    "doNotDisturb": (False, bool, None, None),
    "bannerSeconds": (6, int, 0, 30),
    "pointerSpeed": (0.0, float, -1.0, 1.0),
    "pointerAcceleration": ("adaptive", ["adaptive", "flat"]),
    "naturalScroll": (False, bool, None, None),
    "touchpadNaturalScroll": (True, bool, None, None),
    "tapToClick": (True, bool, None, None),
    "disableWhileTyping": (True, bool, None, None),
    "twoFingerClick": (True, bool, None, None),
    "scrollFactor": (1.0, float, 0.2, 3.0),
    "keyboardLayout": ("us", ["us", "gb", "de", "fr", "es", "us,gb"]),
    "capsLock": ("", ["", "caps:escape", "ctrl:nocaps", "caps:swapescape"]),
    "repeatRate": (25, int, 5, 60),
    "repeatDelay": (600, int, 150, 1000),
    "focusFollowsMouse": (False, bool, None, None),
    "gaps": (5, int, 0, 25),
    "rounding": (14, int, 0, 30),
    "lockMinutes": (5, int, 1, 60),
    "screenOffMinutes": (6, int, 1, 120),
    "suspendMinutes": (15, int, 0, 120),
}


def state_dir():
    return Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "system-configs"


def defaults():
    result = {key: spec[0] for key, spec in SCHEMA.items()}
    path = os.environ.get("DESKTOP_SETTINGS_DEFAULTS")
    if path:
        result.update(json.loads(Path(path).read_text()))
    return result


def validate(values):
    if not isinstance(values, dict) or set(values) - SCHEMA.keys():
        raise ValueError("Unknown settings; no changes saved")
    for key, value in values.items():
        spec = SCHEMA[key]
        if len(spec) == 2:
            if value not in spec[1]:
                raise ValueError(f"Invalid value for {key}")
        else:
            _, kind, low, high = spec
            valid = type(value) is kind if kind in (bool, str) else type(value) in ((int, float) if kind is float else (int,))
            if not valid or (kind not in (bool, str) and not low <= value <= high):
                raise ValueError(f"Invalid value for {key}")
    if values.get("wallpaper"):
        image = Path(values["wallpaper"])
        if not image.is_absolute() or image.suffix.lower() not in (".png", ".jpg", ".jpeg", ".webp"):
            raise ValueError("Choose an existing PNG, JPEG or WebP wallpaper")
    merged = defaults() | values
    if merged["screenOffMinutes"] < merged["lockMinutes"]:
        raise ValueError("Screen off must be at or after automatic lock")
    if 0 < merged["suspendMinutes"] < merged["screenOffMinutes"]:
        raise ValueError("Suspend must be at or after screen off, or disabled")
    return merged


def read_json(name, fallback):
    path = state_dir() / name
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        return fallback


def atomic_write(name, text):
    directory = state_dir()
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, temporary = tempfile.mkstemp(dir=directory, prefix=".settings-")
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(text)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, directory / name)
    finally:
        Path(temporary).unlink(missing_ok=True)


def write_json(name, data):
    atomic_write(name, json.dumps(data, indent=2) + "\n")


@contextlib.contextmanager
def locked():
    state_dir().mkdir(parents=True, exist_ok=True, mode=0o700)
    with (state_dir() / ".lock").open("a") as stream:
        fcntl.flock(stream, fcntl.LOCK_EX)
        yield


def run(command, *, check=True):
    result = subprocess.run(command, text=True, capture_output=True, timeout=10)
    if check and result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or f"{command[0]} failed")
    return result.stdout.strip()


def lua(value):
    if isinstance(value, dict):
        return "{" + ",".join("[" + json.dumps(key) + "]=" + lua(val) for key, val in value.items()) + "}"
    if type(value) is bool:
        return "true" if value else "false"
    return json.dumps(value)


def hypr_config(p):
    return {
        "input": {
            "sensitivity": p["pointerSpeed"], "accel_profile": p["pointerAcceleration"],
            "natural_scroll": p["naturalScroll"], "scroll_factor": p["scrollFactor"],
            "kb_layout": p["keyboardLayout"], "kb_options": p["capsLock"],
            "repeat_rate": p["repeatRate"], "repeat_delay": p["repeatDelay"],
            "follow_mouse": 1 if p["focusFollowsMouse"] else 2,
            "touchpad": {
                "natural_scroll": p["touchpadNaturalScroll"], "tap_to_click": p["tapToClick"],
                "disable_while_typing": p["disableWhileTyping"], "clickfinger_behavior": p["twoFingerClick"],
            },
        },
        "general": {"gaps_in": p["gaps"], "gaps_out": p["gaps"] * 2},
        "decoration": {"rounding": p["rounding"]},
        "animations": {"enabled": not p["reduceMotion"]},
    }


def eval_hypr(code):
    output = run(["hyprctl", "eval", code])
    # hyprctl eval can return 0 even when Lua raises an error.
    if output.lower().startswith("error"):
        raise RuntimeError(output)


def monitor_config(monitor):
    return {
        "output": monitor["name"],
        "mode": f'{monitor["width"]}x{monitor["height"]}@{monitor["refreshRate"]:.5f}',
        "scale": monitor["scale"], "position": f'{monitor["x"]}x{monitor["y"]}',
        "transform": monitor["transform"],
    }


def monitor_lua(config):
    return "hl.monitor(" + lua(config) + ")"


def differences(values, baseline):
    result = {}
    for key, value in values.items():
        if isinstance(value, dict):
            child = differences(value, baseline.get(key, {}))
            if child: result[key] = child
        elif value != baseline.get(key):
            result[key] = value
    return result


def write_overrides(preferences, displays=None):
    displays = read_json("displays.json", {}) if displays is None else displays
    # Only apply keys explicitly changed by the user, preserving future Nix defaults.
    config = differences(hypr_config(preferences), hypr_config(defaults()))
    lines = ["-- Generated by desktop-settings. Edit preferences.json through Settings.", "hl.config(" + lua(config) + ")"]
    lines.extend(monitor_lua(value) for value in displays.values())
    atomic_write("settings.lua", "\n".join(lines) + "\n")


def idle_config(p):
    lines = ['general {', ' lock_cmd = qs ipc call lock lock', ' before_sleep_cmd = qs ipc call lock lock',
             ' after_sleep_cmd = hyprctl dispatch \'hl.dsp.dpms({ action = "on" })\'', '}']
    entries = [(p["lockMinutes"] * 60, "qs ipc call lock lock", None),
               (p["screenOffMinutes"] * 60, 'hyprctl dispatch \'hl.dsp.dpms({ action = "off" })\'',
                'hyprctl dispatch \'hl.dsp.dpms({ action = "on" })\'')]
    if p["suspendMinutes"]:
        entries.append((p["suspendMinutes"] * 60, "systemctl suspend", None))
    for timeout, action, resume in entries:
        lines.extend(["listener {", f" timeout = {timeout}", f" on-timeout = {action}"])
        if resume:
            lines.append(" on-resume = " + resume)
        lines.append("}")
    return "\n".join(lines) + "\n"


def save(values):
    p = validate(values)
    old = validate(read_json("preferences.json", {}))
    if p["wallpaper"] != old["wallpaper"] and p["wallpaper"] and not Path(p["wallpaper"]).is_file():
        raise ValueError("Wallpaper file is no longer available")
    if os.environ.get("HYPRLAND_INSTANCE_SIGNATURE") and hypr_config(old) != hypr_config(p):
        try:
            eval_hypr("hl.config(" + lua(hypr_config(p)) + ")")
        except Exception:
            eval_hypr("hl.config(" + lua(hypr_config(old)) + ")")
            raise
    # Store only overrides, so changing Nix defaults takes effect on next login.
    overrides = {key: value for key, value in p.items() if value != defaults()[key]}
    write_json("preferences.json", overrides)
    write_overrides(p)
    atomic_write("idle.conf", idle_config(p))
    if any(p[key] != old[key] for key in ("lockMinutes", "screenOffMinutes", "suspendMinutes")):
        run(["systemctl", "--user", "restart", "hypridle"], check=False)
    return {"preferences": p}


def monitors():
    return json.loads(run(["hyprctl", "monitors", "-j"]))


def verify_display(config):
    width, height = map(int, config["mode"].split("@")[0].split("x"))
    for attempt in range(20):
        applied = next((m for m in monitors() if m["name"] == config["output"]), {})
        if (applied.get("width"), applied.get("height"), applied.get("scale"), applied.get("transform")) == (width, height, config["scale"], config["transform"]) and abs(applied.get("refreshRate", 0) - float(config["mode"].split("@")[1])) < 0.1:
            return
        time.sleep(0.1)
    raise RuntimeError("Display did not accept the requested configuration")


def revert_display(token):
    pending = read_json("display-pending.json", {})
    if pending.get("token") != token:
        return
    eval_hypr(monitor_lua(pending["old"]))
    verify_display(pending["old"])
    (state_dir() / "display-pending.json").unlink(missing_ok=True)


def preview_display(value):
    if read_json("display-pending.json", {}):
        raise ValueError("Keep or revert the current display change first")
    current = next((m for m in monitors() if m["name"] == value.get("output")), None)
    if current is None:
        raise ValueError("Display is no longer connected")
    mode = value.get("mode")
    modes = {m.replace("Hz", "") for m in current["availableModes"]}
    modes.add(monitor_config(current)["mode"])
    if mode not in modes or value.get("scale") not in [0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3]:
        raise ValueError("Unsupported display mode or scale")
    if type(value.get("transform")) is not int or value["transform"] not in range(4):
        raise ValueError("Unsupported display rotation")
    old = monitor_config(current)
    if os.environ.get("DESKTOP_SETTINGS_FIXED_MODE") == "1":
        size, refresh = mode.split("@")
        if size != f'{current["width"]}x{current["height"]}' or abs(float(refresh) - current["refreshRate"]) > 0.1:
            raise ValueError("This virtual display uses a fixed VNC resolution. Adjust scale instead.")
    new = old | {key: value[key] for key in ["mode", "scale", "transform"]}
    token = uuid.uuid4().hex
    # Start the safety timer before the change, so a crash cannot strand the display.
    write_json("display-pending.json", {"token": token, "old": old, "new": new, "expires": time.time() + 18})
    subprocess.Popen([sys.executable, __file__, "display-watch", token], start_new_session=True,
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        eval_hypr(monitor_lua(new))
        verify_display(new)
    except Exception:
        revert_display(token)
        raise
    return {"token": token}


def keep_display(token):
    pending = read_json("display-pending.json", {})
    if pending.get("token") != token or time.time() > pending.get("expires", 0):
        raise ValueError("Display preview expired")
    verify_display(pending["new"])
    displays = read_json("displays.json", {})
    displays[pending["new"]["output"]] = pending["new"]
    write_json("displays.json", displays)
    write_overrides(validate(read_json("preferences.json", {})), displays)
    (state_dir() / "display-pending.json").unlink(missing_ok=True)
    return {"kept": True}


def snapshot():
    pending = read_json("display-pending.json", {})
    if pending and time.time() > pending.get("expires", 0):
        revert_display(pending["token"])
    info = platform.freedesktop_os_release()
    memory = next(line.split()[1] for line in Path("/proc/meminfo").read_text().splitlines() if line.startswith("MemTotal:"))
    storage = shutil.disk_usage(str(Path.home()))
    return {
        "preferences": validate(read_json("preferences.json", {})), "defaults": defaults(),
        "monitors": monitors(), "pending": read_json("display-pending.json", {}),
        "system": {"hostname": platform.node(), "os": info.get("PRETTY_NAME", "Linux"), "kernel": platform.release(),
                   "fixedDisplayMode": os.environ.get("DESKTOP_SETTINGS_FIXED_MODE") == "1",
                   "memoryGiB": round(int(memory) / 1024**2, 1), "storageTotalGiB": round(storage.total / 1024**3, 1),
                   "storageFreeGiB": round(storage.free / 1024**3, 1),
                   "browser": run(["xdg-settings", "get", "default-web-browser"], check=False),
                   "ip": " · ".join(a["local"] for iface in json.loads(run(["ip", "-j", "address"]))
                                      for a in iface.get("addr_info", []) if a.get("scope") == "global")},
    }


def main():
    action = sys.argv[1]
    if action == "display-watch":
        time.sleep(18)
        with locked():
            revert_display(sys.argv[2])
        return
    if action == "idle-run":
        with locked():
            atomic_write("idle.conf", idle_config(validate(read_json("preferences.json", {}))))
        os.execvp("hypridle", ["hypridle", "-c", str(state_dir() / "idle.conf")])
    with locked():
        if action == "get":
            result = snapshot()
        elif action == "save":
            result = save(json.loads(sys.argv[2]))
        elif action == "display-preview":
            result = preview_display(json.loads(sys.argv[2]))
        elif action == "display-keep":
            result = keep_display(sys.argv[2])
        elif action == "display-revert":
            revert_display(sys.argv[2])
            result = {"reverted": True}
        elif action == "browser":
            entry = sys.argv[2]
            if not re.fullmatch(r"[A-Za-z0-9_.-]+\.desktop", entry):
                raise ValueError("Invalid browser desktop entry")
            run(["xdg-settings", "set", "default-web-browser", entry])
            result = {"browser": run(["xdg-settings", "get", "default-web-browser"])}
        elif action == "reset":
            displays = read_json("displays.json", {})
            result = save(defaults())
            # Keep confirmed monitor modes; resetting a preference must not blank a display.
            write_overrides(defaults(), displays)
        else:
            raise ValueError("Unknown action")
    print(json.dumps(result))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(json.dumps({"error": str(error)}))
        sys.exit(1)
