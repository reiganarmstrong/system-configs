"""Settings operations over maintained desktop tools. No shell or root daemon.

Input is a bounded JSON object on stdin. Each action has a fixed command shape;
privileged operations use the existing PolicyKit agent. Nix-owned packages and
host identity are deliberately outside this mutable interface.
"""
import configparser
import csv
import uuid
import json
import os
from pathlib import Path
import pwd
import re
import subprocess
import sys
import time
from urllib.parse import urlsplit

from settings import locked, read_json, write_json, state_dir, validate, apply_appearance

APP_ID = re.compile(r"[A-Za-z0-9_][A-Za-z0-9_.-]{0,249}")
FLATPAK_ID = re.compile(r"[A-Za-z][A-Za-z0-9_-]*(?:\.[A-Za-z0-9_-]+){2,}")
PRINTER = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,62}")
PKEXEC = "/run/wrappers/bin/pkexec"
SYSTEMCTL = os.environ.get("DESKTOP_ADMIN_SYSTEMCTL", "/run/current-system/sw/bin/systemctl")
LPADMIN = os.environ.get("DESKTOP_ADMIN_LPADMIN", "/run/current-system/sw/bin/lpadmin")
MIMES = {"browser": ["x-scheme-handler/http", "x-scheme-handler/https", "text/html"],
         "files": ["inode/directory"], "text": ["text/plain"], "pdf": ["application/pdf"],
         "audio": ["audio/mpeg", "audio/ogg"], "video": ["video/mp4", "video/webm"],
         "mail": ["x-scheme-handler/mailto"]}


# Sections whose snapshots an action can change; refreshed after success and failure.
REFRESH = {"startup": ["apps"], "default-app": ["defaults"], "app-install": ["apps", "updates"],
           "app-remove": ["apps", "updates"], "app-job-dismiss": ["apps", "updates"], "storage": ["storage"],
           "empty-trash": ["storage"], "timezone": ["time"], "printer": ["printers"],
           "update": ["updates", "apps"], "network-profile": ["network"], "tailscale": ["network"]}
JOB = re.compile(r"desktop-flatpak-(install|remove)@([A-Za-z0-9_.-]+)\.service|desktop-flatpak-(update)\.service")


class AuthenticationCancelled(Exception):
    """The PolicyKit prompt was dismissed or not completed; nothing changed."""


def execute(argv, *, timeout=20, required=True):
    result = subprocess.run(argv, text=True, capture_output=True, timeout=timeout,
                            env=os.environ | {"LC_ALL": "C.UTF-8"})
    if required and result.returncode:
        message = result.stderr.strip() or result.stdout.strip() or "The operation failed."
        # pkexec documents 126 as a dismissed dialog; 127 (not authorized) stays an error.
        # timedated reports a cancelled or failed interactive check as "Access denied".
        if (argv[0] == PKEXEC and result.returncode == 126) or (argv[0] == "timedatectl" and "Access denied" in message):
            raise AuthenticationCancelled("Authentication was cancelled or not completed. Nothing was changed.")
        raise RuntimeError(message[-2000:])
    return result.stdout.strip() if result.returncode == 0 else ""


def fields(value, allowed, required=()):
    if not isinstance(value, dict) or set(value) - set(allowed) or set(required) - set(value):
        raise ValueError("Invalid settings request")
    return value


def text(value, maximum=255):
    if not isinstance(value, str) or not value or len(value) > maximum or any(ord(c) < 32 for c in value):
        raise ValueError("Invalid text value")
    return value


def boolean(value):
    if type(value) is not bool:
        raise ValueError("Expected an on/off value")
    return value


def app_info(identifier):
    if not isinstance(identifier, str) or not APP_ID.fullmatch(identifier.removesuffix(".desktop")):
        raise ValueError("Invalid application")
    from gi.repository import GioUnix
    app = GioUnix.DesktopAppInfo.new(identifier if identifier.endswith(".desktop") else identifier + ".desktop")
    if app is None:
        raise ValueError("This application is no longer installed")
    return app


def startup_ids():
    values = read_json("startup.json", [])
    if not isinstance(values, list) or any(not isinstance(v, str) or not APP_ID.fullmatch(v) for v in values):
        raise ValueError("Startup preferences are invalid; the file has not been changed")
    return values


def startup_run():
    # Preferences survive rebuilds; applications run once per compositor session.
    with locked():
        apply_appearance(validate(read_json("preferences.json", {})))
    # Niri's socket is named for the compositor's process, so it is new each session.
    signature = os.path.basename(os.environ.get("NIRI_SOCKET", ""))
    if not signature or not re.fullmatch(r"[A-Za-z0-9_.-]+", signature):
        return {"started": 0}
    marker = Path(os.environ.get("XDG_RUNTIME_DIR", "/run/user/" + str(os.getuid()))) / ("desktop-startup-" + signature)
    values = startup_ids()
    try:
        with marker.open("x"): pass
    except FileExistsError:
        return {"started": 0}
    count = 0
    for identifier in values:
        try:
            app_info(identifier)
            execute(["qs", "ipc", "call", "launcher", "launch", identifier], timeout=5)
            count += 1
        except (ValueError, RuntimeError, subprocess.TimeoutExpired):
            continue
    return {"started": count}


def flatpaks():
    installed = []
    for scope in ("system", "user"):
        output = execute(["flatpak", "list", "--" + scope, "--app", "--columns=application,name,version"], required=False)
        for line in output.splitlines():
            row = line.split("\t")
            if len(row) >= 2:
                installed.append({"id": row[0], "name": row[1], "version": row[2] if len(row) > 2 else "", "scope": scope})
    return installed


def app_permissions(identifier, scope):
    if not isinstance(identifier, str) or not FLATPAK_ID.fullmatch(identifier) or scope not in ("user", "system"):
        raise ValueError("Invalid application")
    raw = execute(["flatpak", "info", "--" + scope, "--show-permissions", identifier])
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.read_string(raw)
    context = dict(parser["Context"]) if parser.has_section("Context") else {}
    return {"id": identifier, "scope": scope, "permissions": raw,
            "network": "network" in context.get("shared", "").split(";"),
            "filesystems": [v for v in context.get("filesystems", "").split(";") if v],
            "devices": [v for v in context.get("devices", "").split(";") if v]}


def unit_status(unit, user=False):
    output = execute(["systemctl", *(["--user"] if user else []), "show", unit,
                      "--property=LoadState,ActiveState,SubState,Result,ExecMainStatus,StateChangeTimestamp,InvocationID"], required=False)
    return dict(line.split("=", 1) for line in output.splitlines() if "=" in line)


def jobs():
    output = execute(["systemctl", "--user", "list-units", "--all", "--output=json", "--no-pager", "desktop-flatpak-*.service"], required=False)
    result = []
    for row in json.loads(output or "[]"):
        name = row.get("unit", "")
        match = JOB.fullmatch(name)
        if not match:
            continue
        status = unit_status(name, True)
        job = {"unit": name, "operation": match[1] or match[3], "app": match[2] or "", **status}
        if status.get("ActiveState") == "failed":
            # The job's own output says why it failed; systemd's lines only say that it did.
            # Fall back to them when the job printed nothing.
            # The journal persists, so only the latest run counts.
            run = [f"_SYSTEMD_INVOCATION_ID={status['InvocationID']}"] if status.get("InvocationID") else []
            log = execute(["journalctl", "--user", f"_SYSTEMD_USER_UNIT={name}", *run, "--lines=4", "--output=cat", "--no-pager"], required=False)
            if not log.strip():
                log = execute(["journalctl", "--user", "--unit", name, "--lines=4", "--output=cat", "--no-pager"], required=False)
            job["log"] = log[-600:]
        result.append(job)
    return result


def handlers(mime):
    """Apps that declare support for a MIME type, as GIO resolves them."""
    from gi.repository import Gio
    return [{"id": app.get_id(), "name": app.get_display_name(), "visible": app.should_show()}
            for app in Gio.AppInfo.get_all_for_type(mime) if app.get_id()]


def text_editors():
    # Some editors (VSCodium) omit MimeType; the freedesktop TextEditor
    # category specifically means an application that edits plain text.
    from gi.repository import Gio
    return [{"id": app.get_id(), "name": app.get_display_name(), "visible": app.should_show()}
            for app in Gio.AppInfo.get_all() if app.get_id() and "TextEditor" in (app.get_categories() or "").split(";")]


def candidates(kind):
    apps = handlers(MIMES[kind][0]) + (text_editors() if kind == "text" else [])
    return list({app["id"]: app for app in apps}.values())


def default_handler(mime):
    from gi.repository import Gio
    app = Gio.AppInfo.get_default_for_type(mime, False)
    return {"id": app.get_id(), "name": app.get_display_name()} if app and app.get_id() else None


def default_apps():
    result = {}
    for kind, mimes in MIMES.items():
        current = default_handler(mimes[0])
        apps = [{"id": a["id"], "name": a["name"]} for a in candidates(kind) if a["visible"]]
        # Always show the current handler, even a hidden one, so the choice is visible.
        if current and not any(a["id"] == current["id"] for a in apps):
            apps.append(current)
        result[kind] = {"current": current["id"] if current else "",
                        "apps": sorted(apps, key=lambda a: a["name"].lower())}
    return result


def block_devices():
    result = json.loads(execute(["lsblk", "--json", "--bytes", "--paths", "--output", "NAME,TYPE,SIZE,FSTYPE,LABEL,MOUNTPOINTS,RO,RM,MODEL"]))
    volumes, drives = [], []
    home = str(Path.home())
    def visit(node):
        mounts = [m for m in (node.get("mountpoints") or []) if m]
        protected = any(m in {"/", "/boot", "/boot/efi", "/efi", "/nix", "/nix/store", "/usr", "/var", "/etc", "/home"} or home == m or home.startswith(m.rstrip("/") + "/") for m in mounts)
        children = [visit(c) for c in (node.get("children") or [])]
        protected = protected or any(children)
        value = {"device": node["name"], "name": node.get("label") or (node.get("model") or "").strip() or node["name"],
                 "sizeGiB": round(int(node.get("size") or 0) / 1024**3, 2), "filesystem": node.get("fstype") or "",
                 "mounts": mounts, "protected": protected, "readOnly": bool(node.get("ro")), "removable": bool(node.get("rm"))}
        if node.get("fstype"):
            volumes.append(value)
        if node.get("type") == "disk": drives.append(value)
        return protected
    for device in result.get("blockdevices", []): visit(device)
    return {"volumes": volumes, "drives": drives}


def storage_operation(action, device):
    text(device)
    data = block_devices()
    candidates = data["drives"] if action == "eject" else data["volumes"]
    volume = next((v for v in candidates if v["device"] == device), None)
    if not volume or volume["protected"]:
        raise ValueError("System and home volumes cannot be disconnected here")
    if action == "eject":
        if not volume["removable"]: raise ValueError("This drive is not removable")
        execute(["udisksctl", "power-off", "--block-device", device], timeout=60)
    elif action in ("mount", "unmount"):
        if action == "mount" and volume["filesystem"] not in {"ext2", "ext3", "ext4", "btrfs", "xfs", "vfat", "exfat", "ntfs", "ntfs3", "iso9660", "udf"}:
            raise ValueError("Use Disks to unlock or manage this filesystem")
        execute(["udisksctl", action, "--block-device", device], timeout=60)
    else: raise ValueError("Invalid storage operation")


def network_profiles():
    output = execute(["nmcli", "-t", "-f", "UUID,NAME,TYPE,DEVICE", "connection", "show"], required=False)
    return [{"uuid": row[0], "name": row[1], "type": row[2], "active": row[3] not in ("", "--")}
            for row in csv.reader(output.splitlines(), delimiter=":", escapechar="\\", quoting=csv.QUOTE_NONE)
            if len(row) == 4 and row[2] in ("vpn", "wireguard")]


def time_status():
    output = execute(["timedatectl", "show", "--property=Timezone", "--property=NTP", "--property=NTPSynchronized", "--property=LocalRTC"], required=False)
    data = dict(line.split("=", 1) for line in output.splitlines() if "=" in line)
    return {"timezone": data.get("Timezone", "UTC"), "networkTime": data.get("NTP") == "yes",
            "synchronized": data.get("NTPSynchronized") == "yes", "locale": os.environ.get("LANG", "en_US.UTF-8"),
            "zones": execute(["timedatectl", "list-timezones"]).splitlines()}


def printers():
    output = execute(["lpstat", "-p"], required=False)
    queues = []
    for line in output.splitlines():
        match = re.match(r"printer (\S+) (.+)", line)
        if match: queues.append({"name": match[1], "status": match[2]})
    default = execute(["lpstat", "-d"], required=False)
    default = default.partition(": ")[2]
    pending = execute(["lpstat", "-o", "-u", pwd.getpwuid(os.getuid()).pw_name], required=False)
    return {"printers": queues, "default": default, "jobs": [line.split()[0] for line in pending.splitlines() if line.split()],
            "available": unit_status("cups.service").get("ActiveState") == "active"}


def printer_operation(action, data):
    if action == "add":
        fields(data, ["name", "uri"], ["name", "uri"])
        name, uri = text(data["name"], 63), text(data["uri"], 2048)
        parsed = urlsplit(uri)
        if not PRINTER.fullmatch(name) or parsed.scheme not in ("ipp", "ipps") or not parsed.hostname or parsed.username or parsed.password:
            raise ValueError("Use a queue name and an ipp:// or ipps:// printer address without credentials")
        execute([PKEXEC, LPADMIN, "-p", name, "-v", uri, "-m", "everywhere", "-E"], timeout=120)
    elif action in ("default", "remove"):
        fields(data, ["name"], ["name"])
        name = data["name"]
        if not isinstance(name, str) or not PRINTER.fullmatch(name) or name not in {p["name"] for p in printers()["printers"]}:
            raise ValueError("Choose an installed printer")
        execute(["lpoptions", "-d", name] if action == "default" else [PKEXEC, LPADMIN, "-x", name], timeout=120)
    elif action == "cancel":
        fields(data, ["job"], ["job"])
        job = data["job"]
        if not isinstance(job, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*-[0-9]+", job) or job not in printers()["jobs"]:
            raise ValueError("Choose one of your pending print jobs")
        execute(["cancel", job])
    else: raise ValueError("Invalid printer operation")


def online_accounts():
    # Read presentation data only. Secrets remain in GOA and the keyring.
    from gi.repository import Gio, GLib
    try:
        bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        reply = bus.call_sync("org.gnome.OnlineAccounts", "/org/gnome/OnlineAccounts",
                              "org.freedesktop.DBus.ObjectManager", "GetManagedObjects", None, None,
                              Gio.DBusCallFlags.NONE, 3000, None).unpack()[0]
        return [{"provider": props["org.gnome.OnlineAccounts.Account"].get("ProviderName", "Account"),
                 "identity": props["org.gnome.OnlineAccounts.Account"].get("PresentationIdentity", "")}
                for props in reply.values() if "org.gnome.OnlineAccounts.Account" in props]
    except GLib.Error:
        return []


def snapshot(section):
    if section == "apps":
        operations = jobs()
        return {"installed": flatpaks(), "startup": startup_ids(), "jobs": operations}
    if section == "defaults": return default_apps()
    if section == "storage":
        import shutil
        usage = shutil.disk_usage(Path.home())
        return block_devices() | {"freeGiB": round(usage.free / 1024**3, 1), "totalGiB": round(usage.total / 1024**3, 1),
                                  "trashCount": len(list((Path.home() / ".local/share/Trash/info").glob("*.trashinfo")))}
    if section == "time": return time_status()
    if section == "printers": return printers()
    if section == "accounts": return {"online": online_accounts(), "user": pwd.getpwuid(os.getuid()).pw_name,
                                       "fullName": pwd.getpwuid(os.getuid()).pw_gecos.split(",")[0], "home": str(Path.home())}
    if section == "updates":
        config = json.loads(os.environ.get("DESKTOP_ADMIN_CONFIG", "{}"))
        current = str(Path("/run/current-system").resolve())
        prepared = str(Path("/nix/var/nix/profiles/system").resolve())
        return {"systemEnabled": config.get("updates", False), "source": config.get("source", ""),
                "system": unit_status("nixos-upgrade.service"), "apps": unit_status("flatpak-update.service"),
                "userApps": unit_status("desktop-flatpak-update.service", True), "jobs": jobs(),
                "rebootRequired": config.get("updates", False) and current != prepared}
    if section == "network":
        output = execute(["tailscale", "status", "--json", "--peers=false"], required=False)
        data = json.loads(output or "{}")
        return {"profiles": network_profiles(), "state": data.get("BackendState", "Unavailable"), "name": data.get("Self", {}).get("DNSName", "").rstrip("."),
                "addresses": data.get("TailscaleIPs", [])}
    raise ValueError("Unknown settings page")


def perform(action, data):
    if action == "snapshot":
        fields(data, ["section"], ["section"])
        section = data["section"]
        return {"section": section, "data": snapshot(section)}
    if action == "startup-run":
        fields(data, [])
        return startup_run()
    if action == "startup":
        fields(data, ["id", "enabled"], ["id", "enabled"])
        identifier = text(data["id"]).removesuffix(".desktop")
        if not APP_ID.fullmatch(identifier): raise ValueError("Invalid application")
        enabled = boolean(data["enabled"])
        if enabled: app_info(identifier)
        with locked():
            values = startup_ids()
            values = sorted(set(values + [identifier])) if enabled else [v for v in values if v != identifier]
            write_json("startup.json", values)
        return {"refresh": REFRESH[action]}
    if action == "default-app":
        fields(data, ["kind", "id"], ["kind", "id"])
        kind = data["kind"]
        if not isinstance(kind, str) or kind not in MIMES: raise ValueError("Unknown default application type")
        app = app_info(text(data["id"]))
        if app.get_id() not in {h["id"] for h in candidates(kind)}:
            raise ValueError(f"{app.get_display_name()} cannot open this type of file or link")
        if not app.set_as_default_for_type(MIMES[kind][0]): raise RuntimeError("Could not change the default application")
        # Related types only follow when the app declares them too.
        for mime in MIMES[kind][1:]:
            if app.get_id() in {h["id"] for h in handlers(mime)}: app.set_as_default_for_type(mime)
        return {"refresh": REFRESH[action]}
    if action == "app-open":
        fields(data, ["id", "scope"], ["id", "scope"])
        identifier, scope = data["id"], data["scope"]
        if not isinstance(identifier, str) or not FLATPAK_ID.fullmatch(identifier) or scope not in ("user", "system"):
            raise ValueError("Invalid application")
        if not any(app["id"] == identifier and app["scope"] == scope for app in flatpaks()):
            raise ValueError("This application is no longer installed")
        subprocess.Popen(["flatpak", "run", "--" + scope, identifier], stdin=subprocess.DEVNULL,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        return {"opened":True}
    if action == "app-detail":
        fields(data, ["id", "scope"], ["id", "scope"])
        return {"section": "appDetail", "data": app_permissions(data["id"], data["scope"])}
    if action == "app-reset-permissions":
        fields(data, ["id", "scope"], ["id", "scope"])
        app_permissions(data["id"], data["scope"])
        execute(["flatpak", "override", "--user", "--reset", data["id"]])
        return {"section": "appDetail", "data": app_permissions(data["id"], data["scope"])}
    if action == "app-search":
        fields(data, ["query"], ["query"])
        query = text(data["query"].strip() if isinstance(data["query"], str) else data["query"], 100)
        output = execute(["flatpak", "search", "--columns=application,name,description,remotes", "--", query], timeout=60)
        rows = []
        for line in output.splitlines():
            row = line.split("\t")
            if len(row) >= 4 and FLATPAK_ID.fullmatch(row[0]) and "flathub" in row[3].split(","):
                rows.append({"id": row[0], "name": row[1], "description": row[2]})
        return {"section": "appSearch", "data": {"query":query, "items":rows[:30]}}
    if action in ("app-install", "app-remove"):
        fields(data, ["id"], ["id"])
        identifier = data["id"]
        if not isinstance(identifier, str) or len(identifier) > 255 or not FLATPAK_ID.fullmatch(identifier): raise ValueError("Invalid Flatpak application")
        if action == "app-remove" and not any(a["id"] == identifier and a["scope"] == "user" for a in flatpaks()):
            raise ValueError("Only applications added for your account can be removed here")
        operation = "install" if action == "app-install" else "remove"
        execute(["systemctl", "--user", "start", "--no-block", f"desktop-flatpak-{operation}@{identifier}.service"])
        return {"refresh": REFRESH[action]}
    if action == "app-job-dismiss":
        fields(data, ["unit"], ["unit"])
        unit = data["unit"]
        if not isinstance(unit, str) or not JOB.fullmatch(unit):
            raise ValueError("Invalid application operation")
        if not any(j["unit"] == unit and j.get("ActiveState") == "failed" for j in jobs()):
            raise ValueError("This operation is no longer marked as failed")
        execute(["systemctl", "--user", "reset-failed", unit])
        return {"refresh": REFRESH[action]}
    if action == "storage":
        fields(data, ["operation", "device"], ["operation", "device"])
        storage_operation(data["operation"], data["device"])
        return {"refresh": REFRESH[action]}
    if action == "empty-trash":
        fields(data, [])
        execute(["gio", "trash", "--empty"], timeout=60)
        return {"refresh": REFRESH[action]}
    if action == "timezone":
        fields(data, ["zone"], ["zone"])
        zone = data["zone"]
        if not isinstance(zone, str) or len(zone) > 128 or zone not in execute(["timedatectl", "list-timezones"]).splitlines():
            raise ValueError("Choose a valid time zone")
        execute(["timedatectl", "set-timezone", zone], timeout=120)
        return {"refresh": REFRESH[action]}
    if action == "printer":
        fields(data, ["operation", "name", "uri", "job"], ["operation"])
        printer_operation(data["operation"], {k: v for k, v in data.items() if k != "operation"})
        return {"refresh": REFRESH[action]}
    if action == "update":
        fields(data, ["kind"], ["kind"])
        kind = data["kind"]
        if kind == "user-apps": execute(["systemctl", "--user", "start", "--no-block", "desktop-flatpak-update.service"])
        elif kind == "system-apps": execute([PKEXEC, SYSTEMCTL, "start", "--no-block", "flatpak-update.service"], timeout=120)
        elif kind == "system" and json.loads(os.environ.get("DESKTOP_ADMIN_CONFIG", "{}")).get("updates"):
            execute([PKEXEC, SYSTEMCTL, "start", "--no-block", "nixos-upgrade.service"], timeout=120)
        else: raise ValueError("This update is not available on this machine")
        return {"refresh": REFRESH[action]}
    if action == "network-profile":
        fields(data, ["uuid", "enabled"], ["uuid", "enabled"])
        identifier = str(uuid.UUID(data["uuid"]))
        enabled = boolean(data["enabled"])
        if identifier not in {p["uuid"] for p in network_profiles()}: raise ValueError("Choose a saved VPN connection")
        execute(["nmcli", "--wait", "15", "connection", "up" if enabled else "down", "uuid", identifier], timeout=20)
        return {"refresh": REFRESH[action]}
    if action == "tailscale":
        fields(data, ["enabled"], ["enabled"])
        enabled = boolean(data["enabled"])
        if enabled and snapshot("network")["state"] == "NeedsLogin": raise ValueError("Sign in to Tailscale first")
        # Only a bare "tailscale up" reconnects without restating every
        # non-default preference; any flag, even --timeout, triggers that check.
        try:
            execute(["tailscale", "up"] if enabled else ["tailscale", "down"], timeout=15)
        except subprocess.TimeoutExpired:
            if not enabled: raise
            return {"refresh": REFRESH[action], "notice": "Tailscale is still connecting."}
        return {"refresh": REFRESH[action]}
    raise ValueError("Unknown settings operation")


def main():
    action = sys.argv[1] if len(sys.argv) == 2 else ""
    payload = sys.stdin.read(16385)
    if len(payload) > 16384: raise ValueError("Settings request is too large")
    data = json.loads(payload or "{}")
    if not isinstance(data, dict): raise ValueError("Expected a settings object")
    print(json.dumps(perform(action, data)))


if __name__ == "__main__":
    try: main()
    except Exception as error:
        action = sys.argv[1] if len(sys.argv) == 2 else ""
        message = str(error)
        if isinstance(error, subprocess.TimeoutExpired):
            message = "The operation took too long and was stopped. Try again later."
        # A failed change may still have altered state, so the page re-reads it.
        print(json.dumps({"error": message, "cancelled": isinstance(error, AuthenticationCancelled),
                          "refresh": REFRESH.get(action, [])}))
        sys.exit(1)
