"""Validated, per-user desktop preferences and reversible monitor changes.

Nix owns the defaults. Only explicit user overrides go in preferences.json.
From them this writes settings.kdl, which niri's config includes last; niri
reloads it as soon as it changes, so writing the file applies it and restoring
the file undoes it. No commands are run through a shell, and generated KDL
quotes every string with JSON escaping, which KDL shares.
"""
import contextlib
import fcntl
import json
import os
from pathlib import Path
import platform
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
    "leftHanded": (False, bool, None, None),
    "textScale": (1.0, float, 0.85, 1.5),
    "cursorSize": (24, int, 16, 64),
    "focusFollowsMouse": (True, bool, None, None),
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
    except json.JSONDecodeError as error:
        # Never discard a damaged file automatically; the user may want it.
        raise ValueError(f"{path} is not valid JSON ({error.msg}, line {error.lineno}). "
                         "It has not been changed; fix it or move it aside.") from None


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


def json_text(data):
    return json.dumps(data, indent=2) + "\n"


def write_json(name, data):
    atomic_write(name, json_text(data))


def read_text(name):
    try:
        return (state_dir() / name).read_text()
    except FileNotFoundError:
        return None


def attempt(problems, label, function, *args):
    """Run one recovery step; a failure is recorded without skipping the next."""
    try:
        function(*args)
    except Exception as error:
        problems.append(f"{label}: {error}")


def restore_text(name, previous):
    if previous is None:
        (state_dir() / name).unlink(missing_ok=True)
    else:
        atomic_write(name, previous)


def commit(staged, undo=()):
    """Write generated files, restoring earlier contents if any write fails.

    Each file is replaced atomically, but a crash between two replacements can
    still leave a mix; the files are regenerated from preferences.json on the
    next save. `undo` is a list of (label, function) live-state rollbacks that
    run if a write fails. Every rollback is attempted even if another fails.
    """
    written = []
    try:
        # Reading a backup can fail too; live changes still need recovery.
        previous = {name: read_text(name) for name in staged}
        for name, text in staged.items():
            # A failed atomic write leaves its file untouched, so only
            # completed replacements need restoring.
            atomic_write(name, text)
            written.append(name)
    except Exception as error:
        problems = []
        for name in reversed(written):
            attempt(problems, "restoring " + name, restore_text, name, previous[name])
        for label, function in undo:
            attempt(problems, label, function)
        if problems:
            raise RuntimeError(f"{error}. Recovery was incomplete: " + "; ".join(problems)
                               + ". Saved and running settings may differ until the next successful save.") from error
        raise


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


def kdl_number(value):
    return str(value) if type(value) is int else repr(float(value))


def input_kdl(p):
    def pointer(natural):
        lines = [f'accel-speed {kdl_number(p["pointerSpeed"])}',
                 f'accel-profile {json.dumps(p["pointerAcceleration"])}',
                 f'scroll-factor {kdl_number(p["scrollFactor"])}']
        if natural:
            lines.append("natural-scroll")
        if p["leftHanded"]:
            lines.append("left-handed")
        return lines
    xkb = [f'layout {json.dumps(p["keyboardLayout"])}']
    if p["capsLock"]:
        xkb.append(f'options {json.dumps(p["capsLock"])}')
    touchpad = pointer(p["touchpadNaturalScroll"])
    touchpad += [flag for flag, on in (("tap", p["tapToClick"]), ("dwt", p["disableWhileTyping"])) if on]
    touchpad.append('click-method "clickfinger"' if p["twoFingerClick"] else 'click-method "button-areas"')
    return {
        "keyboard": {"xkb": xkb, "repeat": [f'repeat-rate {p["repeatRate"]}', f'repeat-delay {p["repeatDelay"]}']},
        "mouse": pointer(p["naturalScroll"]),
        "touchpad": touchpad,
        # Focus follows the pointer without scrolling the view to reveal a window.
        "focusFollowsMouse": p["focusFollowsMouse"],
    }


def compositor_config(p):
    """Everything settings.kdl sets from preferences, for change detection."""
    return {"input": input_kdl(p), "gaps": p["gaps"], "rounding": p["rounding"],
            "reduceMotion": p["reduceMotion"], "cursorSize": p["cursorSize"]}


def block(name, lines, indent="    "):
    return [name + " {"] + [indent + line for line in lines] + ["}"]


TRANSFORMS = ["normal", "90", "180", "270"]


def output_kdl(config):
    lines = []
    if config.get("mode") and config["mode"] != "preferred":
        lines.append(f'mode {json.dumps(config["mode"])}')
    if config.get("scale") is not None:
        lines.append(f'scale {kdl_number(config["scale"])}')
    if config.get("transform") is not None:
        lines.append(f'transform {json.dumps(TRANSFORMS[config["transform"]])}')
    return block(f'output {json.dumps(config["output"])}', lines)


def default_display():
    """The host's built-in display from Nix, or None when every output is automatic."""
    value = json.loads(os.environ.get("DESKTOP_SETTINGS_DISPLAY") or "{}")
    return value if value.get("output") else None


def settings_kdl(preferences, displays=None):
    displays = read_json("displays.json", {}) if displays is None else displays
    i = input_kdl(preferences)
    inputs = block("keyboard", block("xkb", i["keyboard"]["xkb"]) + i["keyboard"]["repeat"])
    inputs += block("mouse", i["mouse"]) + block("touchpad", i["touchpad"])
    if i["focusFollowsMouse"]:
        inputs.append('focus-follows-mouse max-scroll-amount="0%"')
    lines = ["// Generated by desktop-settings from preferences.json and displays.json.",
             "// Change these through Settings; edits here are replaced.", ""]
    lines += block("input", inputs)
    lines += block("layout", [f'gaps {preferences["gaps"]}'])
    lines += block("window-rule", [f'geometry-corner-radius {preferences["rounding"]}'])
    lines += block("cursor", [f'xcursor-size {preferences["cursorSize"]}'])
    if preferences["reduceMotion"]:
        lines += block("animations", ["off"])
    outputs = {}
    if default_display():
        outputs[default_display()["output"]] = default_display()
    outputs.update(displays)
    for config in outputs.values():
        lines += output_kdl(config)
    return "\n".join(lines) + "\n"


def check_kdl(text):
    """Reject a settings.kdl that niri would refuse, before it is written."""
    with tempfile.NamedTemporaryFile("w", suffix=".kdl") as candidate:
        candidate.write(text)
        candidate.flush()
        result = subprocess.run(["niri", "validate", "-c", candidate.name], text=True, capture_output=True, timeout=10)
    if result.returncode:
        raise RuntimeError("Niri rejected the settings: " + (result.stderr.strip() or result.stdout.strip()).splitlines()[-1])


def idle_config(p):
    on, off = "niri msg action power-on-monitors", "niri msg action power-off-monitors"
    lines = ['general {', ' lock_cmd = qs ipc call lock lock', ' before_sleep_cmd = qs ipc call lock lock',
             ' after_sleep_cmd = ' + on, '}']
    entries = [(p["lockMinutes"] * 60, "qs ipc call lock lock", None), (p["screenOffMinutes"] * 60, off, on)]
    if p["suspendMinutes"]:
        entries.append((p["suspendMinutes"] * 60, "systemctl suspend", None))
    for timeout, action, resume in entries:
        lines.extend(["listener {", f" timeout = {timeout}", f" on-timeout = {action}"])
        if resume:
            lines.append(" on-resume = " + resume)
        lines.append("}")
    return "\n".join(lines) + "\n"


def apply_appearance(p):
    # Niri takes the cursor size from settings.kdl.
    run(["dconf", "write", "/org/gnome/desktop/interface/text-scaling-factor", str(float(p["textScale"]))])
    run(["dconf", "write", "/org/gnome/desktop/interface/cursor-size", str(p["cursorSize"])])


ARTIFACTS = ("preferences.json", "settings.kdl", "idle.conf")


def save(values):
    p = validate(values)
    old = validate(read_json("preferences.json", {}))
    if p["wallpaper"] != old["wallpaper"] and p["wallpaper"] and not Path(p["wallpaper"]).is_file():
        raise ValueError("Wallpaper file is no longer available")
    # Generate and check everything before touching the session, so a bad
    # value changes nothing. Store only overrides, so Nix default changes
    # still apply. Writing settings.kdl is what applies compositor changes.
    compositor = settings_kdl(p)
    if compositor_config(p) != compositor_config(old):
        check_kdl(compositor)
    staged = dict(zip(ARTIFACTS, (
        json_text({key: value for key, value in p.items() if value != defaults()[key]}),
        compositor, idle_config(p))))
    appearance_changed = any(p[key] != old[key] for key in ("textScale", "cursorSize"))
    undo = []
    if appearance_changed:
        try:
            apply_appearance(p)
        except Exception as error:
            problems = []
            # A step can fail half-applied, so it is always rolled back.
            attempt(problems, "restoring text and cursor size", apply_appearance, old)
            if problems:
                raise RuntimeError(f"{error}. Recovery was incomplete: " + "; ".join(problems)) from error
            raise
        undo.append(("restoring text and cursor size", lambda: apply_appearance(old)))
    commit(staged, undo)
    if any(p[key] != old[key] for key in ("lockMinutes", "screenOffMinutes", "suspendMinutes")):
        run(["systemctl", "--user", "restart", "hypridle"], check=False)
    return {"preferences": p}


def regenerate():
    """Rewrite the generated files from saved state, e.g. after Nix defaults change."""
    p = validate(read_json("preferences.json", {}))
    compositor = settings_kdl(p)
    check_kdl(compositor)
    commit({"settings.kdl": compositor, "idle.conf": idle_config(p)})


def mode_string(mode):
    # Niri matches a mode's refresh rate exactly, to the millihertz.
    return f'{mode["width"]}x{mode["height"]}@{mode["refresh_rate"] / 1000:.3f}'


def monitors():
    """Connected, enabled outputs in the shape the Settings page reads."""
    result = []
    for output in json.loads(run(["niri", "msg", "--json", "outputs"])).values():
        logical = output.get("logical")
        if output.get("current_mode") is None or not logical:
            continue
        current = output["modes"][output["current_mode"]]
        transform = str(logical["transform"]).lower()
        result.append({
            "name": output["name"],
            "description": " ".join(filter(None, (output.get("make"), output.get("model")))) or output["name"],
            "width": current["width"], "height": current["height"], "refreshRate": current["refresh_rate"] / 1000,
            "scale": logical["scale"], "x": logical["x"], "y": logical["y"],
            "transform": TRANSFORMS.index(transform) if transform in TRANSFORMS else 0,
            "availableModes": [mode_string(m) + "Hz" for m in output["modes"]],
        })
    return result


def monitor_config(monitor):
    return {"output": monitor["name"],
            "mode": f'{monitor["width"]}x{monitor["height"]}@{monitor["refreshRate"]:.3f}',
            "scale": monitor["scale"], "transform": monitor["transform"]}


def apply_display(config):
    """Change an output now. Niri forgets this on the next config reload,
    so a kept change is also written to settings.kdl."""
    name = config["output"]
    run(["niri", "msg", "output", name, "mode", config["mode"]])
    run(["niri", "msg", "output", name, "scale", kdl_number(config["scale"])])
    run(["niri", "msg", "output", name, "transform", TRANSFORMS[config["transform"]]])


def verify_display(config):
    for _ in range(20):
        applied = next((m for m in monitors() if m["name"] == config["output"]), None)
        if applied and monitor_config(applied)["mode"] == config["mode"] \
                and applied["transform"] == config["transform"] and abs(applied["scale"] - config["scale"]) < 0.01:
            return
        time.sleep(0.1)
    raise RuntimeError("Display did not accept the requested configuration")


def revert_display(token):
    pending = read_json("display-pending.json", {})
    if pending.get("token") != token:
        return
    # An unplugged output gets its saved settings.kdl block on its next
    # connection; there is nothing to verify, and keeping the record would
    # block Settings.
    if any(m["name"] == pending["old"]["output"] for m in monitors()):
        apply_display(pending["old"])
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
    if mode not in modes or value.get("scale") not in [0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3]:
        raise ValueError("Unsupported display mode or scale")
    if type(value.get("transform")) is not int or value["transform"] not in range(4):
        raise ValueError("Unsupported display rotation")
    old = monitor_config(current)
    if os.environ.get("DESKTOP_SETTINGS_FIXED_MODE") == "1" and mode != old["mode"]:
        raise ValueError("This virtual display uses a fixed VNC resolution. Adjust scale instead.")
    new = old | {key: value[key] for key in ["mode", "scale", "transform"]}
    token = uuid.uuid4().hex
    # Start the safety timer before the change, so a crash cannot strand the display.
    write_json("display-pending.json", {"token": token, "old": old, "new": new, "expires": time.time() + 18})
    subprocess.Popen([sys.executable, __file__, "display-watch", token], start_new_session=True,
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        apply_display(new)
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
    compositor = settings_kdl(validate(read_json("preferences.json", {})), displays)
    check_kdl(compositor)
    commit({"displays.json": json_text(displays), "settings.kdl": compositor})
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
    if action == "regenerate":
        with locked():
            regenerate()
        print(json.dumps({"regenerated": True}))
        return
    if action == "gtk-apply":
        apply_appearance(validate(read_json("preferences.json", {})))
        print(json.dumps({"applied": True}))
        return
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
        elif action == "reset":
            # settings.kdl keeps confirmed monitor modes from displays.json.
            result = save(defaults())
        else:
            raise ValueError("Unknown action")
    print(json.dumps(result))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(json.dumps({"error": str(error)}))
        sys.exit(1)
