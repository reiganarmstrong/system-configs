"""Validated, per-user desktop preferences and reversible monitor changes.

Nix owns the defaults. Only explicit user overrides go in preferences.json.
Hyprland's own options (input, gaps, corners, animations) live in hyprland.lua
and HyprMod, not here. The generated settings.lua only carries the cursor size
and confirmed monitor choices; Hyprland reloads after a successful save.
File writes and live appearance changes are rolled back together on failure.
No commands run through a shell; Lua literals quote every user string.
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

sys.path.insert(0, str(Path(__file__).parent))
from compositor import lua

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
    "textScale": (1.0, float, 0.85, 1.5),
    "cursorSize": (24, int, 16, 64),
    "lockMinutes": (5, int, 1, 60),
    "screenOffMinutes": (6, int, 1, 120),
    "suspendMinutes": (15, int, 0, 120),
}

# Hyprland options Settings used to manage before HyprMod took them over.
# Older preferences.json files may still hold them; they are dropped quietly
# and disappear from the file on the next save.
RETIRED = {"pointerSpeed", "pointerAcceleration", "naturalScroll", "touchpadNaturalScroll", "tapToClick",
           "disableWhileTyping", "twoFingerClick", "scrollFactor", "keyboardLayout", "capsLock",
           "repeatRate", "repeatDelay", "leftHanded", "focusFollowsMouse", "gaps", "rounding"}


def state_dir():
    return Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "system-configs"


def defaults():
    result = {key: spec[0] for key, spec in SCHEMA.items()}
    path = os.environ.get("DESKTOP_SETTINGS_DEFAULTS")
    if path:
        result.update({key: value for key, value in json.loads(Path(path).read_text()).items() if key in SCHEMA})
    return result


def validate(values):
    if not isinstance(values, dict):
        raise ValueError("Unknown settings; no changes saved")
    values = {key: value for key, value in values.items() if key not in RETIRED}
    if set(values) - SCHEMA.keys():
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


def commit(staged, undo=(), activate=None):
    """Write generated files, restoring earlier contents if saving or activation fails.

    Each file is replaced atomically, but a crash between two replacements can
    still leave a mix; the files are regenerated from preferences.json on the
    next save. `undo` is a list of (label, function) live-state rollbacks that
    run if saving or activation fails. Every rollback is attempted even if another fails.
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
        if activate:
            activate()
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


COMPOSITOR_KEYS = ("cursorSize",)


def compositor_config(p):
    return {key: p[key] for key in COMPOSITOR_KEYS}


def default_display():
    """The host's built-in display from Nix, or None when every output is automatic."""
    value = json.loads(os.environ.get("DESKTOP_SETTINGS_DISPLAY") or "{}")
    return value if value.get("output") else None


def settings_lua(p, displays=None):
    displays = read_json("displays.json", {}) if displays is None else displays
    lines = ["-- Generated from the shared desktop preferences.",
             "hl.env(\"XCURSOR_SIZE\", " + lua(str(p["cursorSize"])) + ")"]
    outputs = {default_display()["output"]: default_display()} if default_display() else {}
    outputs.update(displays)
    for output in outputs.values():
        lines.append("hl.monitor(" + lua({"output": output["output"], "mode": output["mode"],
                                         "scale": output["scale"], "transform": output.get("transform", 0)}) + ")")
    return "\n".join(lines) + "\n"


def check_lua(text):
    with tempfile.TemporaryDirectory(prefix="desktop-hypr-check-") as runtime, tempfile.NamedTemporaryFile("w", suffix=".lua") as candidate:
        candidate.write(text)
        candidate.flush()
        result = subprocess.run(["Hyprland", "--verify-config", "-c", candidate.name], text=True, capture_output=True, timeout=10,
                                env=os.environ | {"XDG_RUNTIME_DIR": runtime})
    report = result.stdout.split("Config parsing result:")[-1].strip()
    if result.returncode or report != "config ok":
        raise RuntimeError("Hyprland rejected the settings: " + (report or result.stderr.strip()))


def reload_hyprland():
    if os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
        run(["hyprctl", "reload"])


def idle_config(p):
    on, off = "desktop-compositor power-on", "desktop-compositor power-off"
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
    # Compositor cursor settings also come from the generated Lua.
    run(["dconf", "write", "/org/gnome/desktop/interface/text-scaling-factor", str(float(p["textScale"]))])
    run(["dconf", "write", "/org/gnome/desktop/interface/cursor-size", str(p["cursorSize"])])


ARTIFACTS = ("preferences.json", "settings.lua", "idle.conf")


def save(values):
    p = validate(values)
    old = validate(read_json("preferences.json", {}))
    if p["wallpaper"] != old["wallpaper"] and p["wallpaper"] and not Path(p["wallpaper"]).is_file():
        raise ValueError("Wallpaper file is no longer available")
    # Generate and check everything before touching the session, so a bad
    # value changes nothing. Store only overrides, so Nix default changes
    # still apply. Hyprland needs a reload after saving Lua.
    compositor = settings_lua(p)
    if compositor_config(p) != compositor_config(old):
        check_lua(settings_lua(p))
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
    if compositor_config(p) != compositor_config(old):
        undo.append(("reloading restored Hyprland settings", reload_hyprland))
        commit(staged, undo, activate=reload_hyprland)
    else:
        commit(staged, undo)
    if any(p[key] != old[key] for key in ("lockMinutes", "screenOffMinutes", "suspendMinutes")):
        run(["systemctl", "--user", "restart", "hypridle"], check=False)
    return {"preferences": p}


def regenerate():
    """Rewrite the generated files from saved state, e.g. after Nix defaults change."""
    p = validate(read_json("preferences.json", {}))
    compositor = settings_lua(p)
    check_lua(settings_lua(p))
    commit({"settings.lua": compositor, "idle.conf": idle_config(p)}, [("reloading restored settings", reload_hyprland)], activate=reload_hyprland)


def normalize_hypr_mode(mode):
    match = re.fullmatch(r"(\d+x\d+)@([0-9.]+)Hz", mode)
    return f"{match[1]}@{float(match[2]):.3f}Hz" if match else mode


def hypr_refresh_rate(monitor):
    # DRM's measured clock can differ slightly from Hyprland's advertised
    # refresh (74.995 versus 75.000). Use the advertised mode as its stable ID.
    rates = []
    prefix = f'{monitor["width"]}x{monitor["height"]}@'
    for mode in monitor["availableModes"]:
        if mode.startswith(prefix) and mode.endswith("Hz"):
            rates.append(float(mode[len(prefix):-2]))
    closest = min(rates, key=lambda r: abs(r - monitor["refreshRate"])) if rates else monitor["refreshRate"]
    return closest if abs(closest - monitor["refreshRate"]) < 0.05 else monitor["refreshRate"]


def monitors():
    """Connected, enabled outputs in the shape the Settings page reads."""
    result = []
    for m in json.loads(run(["hyprctl", "-j", "monitors"])):
        result.append({"name": m["name"], "description": m.get("description") or m["name"],
                       "width": m["width"], "height": m["height"], "refreshRate": hypr_refresh_rate(m),
                       "scale": m["scale"], "x": m["x"], "y": m["y"], "transform": m.get("transform", 0),
                       "availableModes": [normalize_hypr_mode(mode) for mode in m["availableModes"]]})
    return result


def monitor_config(monitor):
    return {"output": monitor["name"],
            "mode": f'{monitor["width"]}x{monitor["height"]}@{monitor["refreshRate"]:.3f}',
            "scale": monitor["scale"], "transform": monitor["transform"]}


def apply_display(config):
    """Preview a monitor setting; confirmed choices are persisted to settings.lua."""
    run(["hyprctl", "eval", "hl.monitor(" + lua({"output": config["output"], "mode": config["mode"],
                                               "scale": config["scale"], "transform": config["transform"]}) + ")"])


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
    # An unplugged output gets its saved settings.lua block on its next
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
    compositor = settings_lua(validate(read_json("preferences.json", {})), displays)
    check_lua(settings_lua(validate(read_json("preferences.json", {})), displays))
    commit({"displays.json": json_text(displays), "settings.lua": compositor},
           [("reloading restored settings", reload_hyprland)], activate=reload_hyprland)
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
            # settings.lua keeps confirmed monitor modes from displays.json.
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
