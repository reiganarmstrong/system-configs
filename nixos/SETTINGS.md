# Desktop settings

Open Settings with `Super+,`, the launcher, or the control center gear. The VM and Framework use the same interface and backend. This is a Hyprland desktop, so some GNOME and KDE capabilities do not have a corresponding compositor or service here.

## Coverage

| Page | Available inside Settings | Uses a maintained external tool |
| --- | --- | --- |
| Appearance | Wallpaper, panel opacity, motion, clock, battery percentage, gaps and window corners | File chooser for wallpaper |
| Notifications | Do Not Disturb, banner duration and history controls | |
| Accessibility | Shell text size, GTK text scaling, cursor size, reduced motion and left-handed mouse | Screen reader, magnifier and sticky keys are not integrated |
| Privacy | Pause or clear clipboard history, microphone mute, notification suppression, lock settings and app permission navigation | |
| Accounts & calendars | Current account and connected online-account summaries | Online Accounts for provider authentication, key manager and password change |
| Displays | Resolution, refresh rate, scale, rotation, brightness and timed confirmation with rollback | Display arrangement on native hardware |
| Sound | Default input/output devices, microphone and output levels, mute and individual app levels | Advanced routing, balance and device profiles in Volume Control |
| Keyboard & pointer | Layout, Caps Lock mapping, repeat timing, acceleration, pointer speed, scrolling, touchpad behavior, left-handed mouse and shortcut reference | Custom shortcuts remain in the shared compositor configuration |
| Power & lock | Power profile, idle inhibitor, lock/display-off/suspend timing and session actions | |
| Printers | Add driverless IPP printers, remove queues, choose default and cancel your pending jobs | USB discovery, vendor drivers and unusual printer options |
| Network & VPN | Wi-Fi scanning/joining/forgetting, airplane mode, saved VPN connection toggles, Tailscale state and connection toggle | Ethernet/DNS/proxy/VPN profile editing and enterprise Wi-Fi in NetworkManager's connection editor; initial Tailscale sign-in |
| Bluetooth | Adapter switch, discovery, pairing, connection and forgetting devices | Advanced adapter options in Bluetooth Manager |
| Applications | Open installed apps, search Flathub, install/remove account-local Flatpaks, inspect sandbox permissions and reset account overrides | System-managed apps remain declared in Nix |
| Default apps | Browser, files, text, PDF, audio, video and email handlers, chosen from apps that declare the type (text also lists apps in the TextEditor category) | Types no installed app declares show as unavailable |
| Startup apps | Enable/disable installed apps at graphical login; remove stale entries | System services remain declared in Nix |
| Storage | Capacity, volumes, open/mount/unmount, removable-drive power-off and confirmed Empty Trash | Partitioning, encryption, formatting and diagnostics in Disks |
| Date & time | Search and change system time zone, clock format and seconds; synchronization and locale status | Language and synchronization policy remain declared in Nix |
| Updates | Status and explicit update actions for system generations and system/account Flatpaks; restart-required state | Rollback through the laptop boot menu |
| About | Host/OS/kernel/memory/storage summaries and confirmed desktop-preference reset | |

The app does not claim full GNOME/KDE parity. Advanced accessibility, user creation, fingerprint enrollment, color management, arbitrary device drivers and per-app notification rules are outside its current coverage. Unsupported hardware is disabled or explained. VNC does not forward guest audio.

## Ownership and persistence

Nix supplies packages, services, defaults and hardware policy. Ordinary runtime choices go through the service that owns them rather than modifying generated Nix files:

- NetworkManager and BlueZ own connections and pairing; PipeWire owns audio.
- UDisks owns mounts, CUPS owns printer queues, and systemd-timedated owns the time zone.
- GIO owns MIME associations. Flatpak owns account-local app installs and overrides. GOA/EDS and the keyring own online accounts and secrets.
- `~/.local/state/system-configs/preferences.json` holds explicitly chosen desktop preferences. Generated `settings.lua` and `idle.conf` apply those preferences; `displays.json` holds confirmed monitor choices.
- `startup.json` in the same private state directory lists desktop-entry IDs. Entries launch once per compositor session, not each time the shell restarts. They use the launcher's normal desktop-entry handling, including terminal applications.

Preference reset preserves monitor modes, startup applications, installed apps and accounts. Copying the state directory transfers desktop choices, but monitor identifiers, selected wallpaper paths and account credentials can differ between machines. Network/account secrets are not Git content.

The default time zone is America/New_York on a new installation. `/etc/localtime` is mutable so a time-zone change survives rebuilds and reboots. A host may instead set a static `time.timeZone` in Nix. Clock and calendar code follow the system zone.

Application installs and updates run as background systemd jobs, so closing Settings does not interrupt them. A failed install or remove stays on the Applications page with the job's last output, the `journalctl` command for the full log, Retry and Dismiss. Dismiss resets only that failed job. An update job that has not run since startup is reported as not run, not as succeeded. The laptop's system update prepares a generation from the configured Git repository for the next boot. It does not reboot automatically. Uncommitted local source changes are not fetched by that updater. The test VM receives system updates by rebuilding its VM runner.

## Implementation boundaries

- `modules/home/quickshell/qml/modules/Settings.qml` provides navigation and lazy page loading. The 19 pages live in `modules/settings/`, with the searchable catalog in `Catalog.js`.
- `components/settings/` contains shared rows, entries, sliders, switches and dropdowns. UI text treats device and app names as plain text.
- `services/Prefs.qml` serializes preference changes. `services/SettingsAdmin.qml` runs administrative requests in two lanes: snapshots and permission details in one, changes and searches in the other. A change waiting for PolicyKit therefore does not block unrelated pages from loading. A change refreshes the sections it affects, also after a failure, so switches and dropdowns show the stored state rather than the attempted one. A cancelled authentication is shown as a neutral notice.
- `modules/home/settings/settings.py` validates desktop preferences, stages every generated file, applies the live changes and then writes the files. If any step fails, it restores the files already written and undoes each live change independently. It reports when a restore step also failed. Each file is replaced atomically; a crash between two file renames can still leave the files from different saves.
- `modules/home/settings/admin.py` accepts bounded JSON on stdin. Each operation validates its fields and uses a fixed argument list. It has no shell-command endpoint or privileged daemon. Privileged operations use the normal PolicyKit agent and existing tools.
- The network, Bluetooth and per-app audio pages reuse control-center components. Scan ownership is shared so closing one view does not disable another view's discovery.
- `modules/home/settings/default.nix` packages runtime dependencies and fixed systemd jobs. Capabilities requiring system services belong in `modules/nixos/`.

Keep future controls within these boundaries. Add service-backed operations with validation and semantic tests. Commands launched in a terminal use `$TERMINAL` only when it names one executable (a name or path, no spaces or leading `-`). It is run as `TERMINAL -e PROGRAM ARGS…`; anything else falls back to Ghostty.

Avoid patching vendor applications, collecting credentials in QML, introducing a general root helper or implementing partition editors and account-provider flows.

## Verification

From the repository root:

```sh
nix build --no-link \
  .#checks.x86_64-linux.settings \
  .#checks.x86_64-linux.admin \
  .#checks.x86_64-linux.calendar \
  .#checks.x86_64-linux.dropdowns \
  .#checks.x86_64-linux.clipboardSelection \
  .#checks.x86_64-linux.settingsFailures
```

The preference tests cover validation, failed-change rollback, persistence and display preview recovery. Administrative tests cover application scope, startup behavior, fixed update jobs, device protection, printer/job validation, time-zone validation and permission inspection. They use temporary state and never inspect personal clipboard or account data. The preference tests inject a failure at every write and live-apply step. `settingsFailures` runs the production Settings services and controls headless against fake helpers that fail, refuse or wait as an authentication prompt would. It checks error display, switch and dropdown state, refreshes during a pending change, the Applications page's inline confirmations and the `$TERMINAL` contract.

In an unlocked graphical session, run the native page and scanner lifecycle checks:

```sh
nix shell .#nixosConfigurations.vm.pkgs.python3 -c python3 nixos/tests/settings_ui.py
```

These checks open each page and verify helper completion and shared Wi-Fi scanner ownership. They close Settings and the control center afterwards. The existing `nixos/tests/control_center.py` checks popup animation and cleanup.

Physical printing, removable-drive behavior, touchpad/backlight support, Bluetooth pairing and live account synchronization require the corresponding hardware or accounts. Simulated VM radios and silent audio devices support UI testing but cannot establish laptop hardware compatibility.
