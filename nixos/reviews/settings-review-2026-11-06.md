# Settings and desktop shell review: 2026-11-06

Scope: every working-tree change against `7e2ac10` (`git diff HEAD`, including intent-added files), plus the existing code those changes depend on. I reviewed the 19-page Settings app, `SettingsAdmin`/`Prefs`, `admin.py`/`settings.py`, packaging, the control-center pages reused by Settings, the launcher/dock terminal launch path, clipboard selection, GTK changes and the docs. No AGENTS.md, CLAUDE.md or CONTRIBUTING file exists in the repository. `nixos/SETTINGS.md` and `nixos/README.md` set the intended boundaries, and I did not count delegated features as defects.

Paths below are relative to `nixos/modules/home/quickshell/qml/` unless they start with `nixos/`.

## Summary

The architecture holds up. Every operation has a fixed argv, no shell is involved, PolicyKit is used only where it is needed, writes are atomic and locked, background systemd jobs outlive the window, and services own their own state. The pages are small and consistent. All automated checks pass. The most serious problems are in feedback when something fails:

1. A failed preference save shows its error for a few milliseconds and then clears it. This is a regression from this diff.
2. A switch flipped for a failed or no-op operation stays in the wrong position.
3. Applications places the Remove confirmation and the permission details below the entire app list, out of view.
4. Failed background app jobs show a permanent, anonymous banner, and the "Details are available in Updates" text it shows is false.
5. Default apps offers candidates by desktop category rather than MIME support. In the VM, Volume Control is the only "Music and audio" and "Video" choice, and the actual mail handler is shown as "Unavailable".

None of these risk data loss. 1 and 2 together mean a failed setting change can look successful.

## Tests run

| Test | Result |
| --- | --- |
| `nix build --no-link .#checks.x86_64-linux.{settings,admin,calendar,dropdowns,clipboardSelection}` | Pass. The derivations were already in the store, so this confirmed the current sources build and pass without a fresh run. |
| `nixos/tests/settings_ui.py` in the VM session | 2/2 OK (10.5 s) |
| `nixos/tests/control_center.py` in the VM session | 2/2 OK |
| Isolated Quickshell harness: production `Prefs.qml` with a fake `desktop-settings` that fails `save` | Reproduced finding 1 |
| Isolated Quickshell harness: `Switch` bound through an intermediate property, as in `SettingToggle` | Reproduced finding 2 |
| VNC visual review: Defaults, Applications, Updates, Storage, Accessibility, Network, Power, Date & time; minimum window 820×540 at 150% text; keyboard Tab/arrow navigation | Findings 3–6 and 9–11 |
| Live time-zone change through Settings with the PolicyKit dialog, then reverted; cancelled-authentication path | Bar clock follows a live zone change. Cancellation produces an error (finding 7). |
| Simulated failed app job: a harmless `desktop-flatpak-remove@org.example.ReviewFixture.service`, removed afterwards with `reset-failed` | Reproduced finding 4 |

Restored afterwards: time zone America/New_York, text scale 100%, window 960×680, Caffeine false, Settings open on Appearance. Temporary harnesses and the failed unit were removed. I did not read clipboard contents or account details.

## Confirmed defects (highest priority first)

### 1. Failed preference saves are silently cleared (Medium-High, confidence high)

`services/Prefs.qml:78-83`. After a failed `save`, the handler sets `error` and queues `["get"]` to resynchronise. This diff added `root.error = ""` to the success branch, so the `get` that follows immediately clears the error.

Reproduction (harness in the VM, using the production `Prefs.qml` and a `desktop-settings` that fails `save`):

```
ERR=[Simulated save failure] action=save
ERR=[] action=get
FINAL=[] ready=true
```

Impact: a rejected change (Hyprland eval failure, missing wallpaper, state write failure) shows an error in the Settings header for a few milliseconds. The value then reverts in `Prefs.values` with no explanation, or, because of finding 2, does not visibly revert at all.

Smallest fix: clear `error` only after a successful `save`, `reset` or `display-*`, not after a `get`. For example, change line 83 to `if (root.action !== "get") root.error = "";`. Add a harness test like the one above to the existing Qt Quick test infrastructure (`nixos/tests/dropdowns`).

### 2. Switches can show a state that the backend never accepted (Medium, confidence high)

`components/settings/SettingToggle.qml:11,19`. The inner `Switch` is bound to `row.checked`. Clicking it flips `Switch.checked` internally. If the request fails, or the next snapshot produces the same value, `row.checked` never changes, so the binding never fires again and the switch stays flipped.

Reproduction (harness with the same structure):

```
after click: switch=true row=false
after unchanged refresh: switch=true
```

A direct binding to an object property recovers when the object is replaced. The intermediate `row.checked` property used by every `SettingToggle` does not.

Affected: every `SettingToggle` whose request can fail or be refused. That covers Network VPN profiles and Tailscale (`modules/settings/NetworkPage.qml`; `SettingsAdmin` does not refresh on error), Startup apps, clipboard capture, Airplane mode, and every preference toggle when a save fails (see 1). `SettingChoice`/`ChoiceBox` (`SettingChoice.qml:14,17`) likely has the same structure through `currentIndex`. I did not isolate that case. In the time-zone test the dropdown only came back into sync because the search filter changed its model.

Smallest fix: make the control display backend state only. Set `checkable: false` and use `onClicked: row.toggled(!row.checked)`, keeping `checked: row.checked`. Preference toggles keep instant feedback because `Prefs.set` updates `values` immediately. For admin toggles, `SettingsAdmin` should refresh the affected section on error as well as on success.

### 3. Applications: Remove confirmation and permission details appear off-screen (Medium, confidence high)

`modules/settings/AppsPage.qml:144` (remove confirmation), `:167-176` (permissions section and reset confirmation). These rows come after the `Repeater` over every installed app (about 20 visible entries in the VM, more on a real machine).

Reproduction: Applications → clear the filter → click **Permissions** on Zen. Nothing visible changes. The details render about 1,500 px below the visible area. With the filter "zen" they appear directly underneath (screenshots `apps-perm` and `apps-perm2`). The same happens with **Remove…** on an account Flatpak: the destructive confirmation is out of view, so the click appears to do nothing.

Smallest fix: render the confirmation and permission details inside the delegate for the selected row (`visible: page.removeId === appRow.modelData.id`). Alternatively, put them in a fixed panel above the list. Use the app name in the confirmation title rather than the ID.

### 4. Failed background app jobs: permanent, anonymous banner pointing to a nonexistent "Updates" detail (Medium, confidence high)

`modules/settings/AppsPage.qml:208-209`, `modules/settings/UpdatesPage.qml` (does not render `info.jobs`), `nixos/modules/home/settings/admin.py:132-139`, `nixos/modules/home/settings/default.nix:128-142`.

Reproduction: start a failing `desktop-flatpak-remove@org.example.ReviewFixture.service`. Applications then shows "An app operation failed — Check your connection and try again. Details are available in Updates." Updates shows nothing about it. It still reports both Flatpak rows as "Last operation succeeded" (screenshots `failjob` and `failupd`). The banner names no app, cannot be dismissed, and remains until logout because nothing runs `reset-failed`.

Smallest fix: return the app ID (the unit instance) and `Result` in `jobs()`, and show "Installing/removing *Name* failed" with Retry and Dismiss actions. Dismiss would be a fixed `systemctl --user reset-failed desktop-flatpak-…@<validated id>.service` operation. Change the text to point to `journalctl --user -u …`, or show the last few log lines, rather than to Updates.

### 5. Default apps offers apps that cannot open the type and hides the real handler (Medium, confidence high)

`modules/settings/DefaultsPage.qml:9-56`, `nixos/modules/home/settings/admin.py:249,294-301`. Candidates come from `Categories=` alone. `set_as_default_for_type` does not check the app's `MimeType`, so the backend accepts any choice.

Observed in the VM (screenshots `defaults` and `defaults-audio`):

- "Music and audio" and "Video" offer only **Volume Control** (pavucontrol, `AudioVideo;Audio;Mixer`). Choosing it would make the mixer the handler for MP3/MP4.
- "PDF documents" includes GNOME Calendar (`Office`).
- "Email links" shows **Unavailable** while `xdg-mime query default x-scheme-handler/mailto` returns `app.zen_browser.zen.desktop`, so the current handler cannot be seen.

Smallest fix: build the candidates in the `defaults` snapshot with `Gio.AppInfo.get_all_for_type(mime)` (ID and name) for the first MIME of each kind, and always include the current default. In `default-app`, reject apps that do not support the type. Add a semantic test for that rejection. This also removes the duplicated category tables from QML.

### 6. Updates reports "Last operation succeeded" for jobs that never ran (Low-Medium, confidence high)

`modules/settings/UpdatesPage.qml:15`. systemd reports `Result=success` with an empty `StateChangeTimestamp` for units that have not run since boot. In the VM, both Flatpak rows show "Last operation succeeded" with no time (screenshot `updates`). On the laptop this appears after every reboot, including when the last real run failed.

Smallest fix: if `StateChangeTimestamp` is empty, show "Not run since startup". Show "succeeded" only when there is a timestamp. The `jobs()` data from finding 4 could also feed this page.

### 7. One serialized admin queue is held by authentication prompts and long searches (Medium, confidence high for the mechanism)

`services/SettingsAdmin.qml:30-50`, `nixos/modules/home/settings/admin.py:214,323,352,362-364` (timeouts of 60–120 s). All snapshots and mutations share one worker. While the PolicyKit dialog for a time-zone change was open, `adminBusy` stayed true and the sidebar showed "Applying…". Every other page's refresh and action waits behind it. That includes the 3-second Updates poll and the Apps job poll, and lasts up to the 120 s `pkexec` timeout or the 60 s `flatpak search`. Snapshots on newly opened pages show "Loading…" or old data during that time.

Also observed: cancelling authentication reports **"Failed to set time zone: Access denied"** in red (screenshot `cancel2`), and the error stays while the user keeps editing on the page.

Smallest fix: keep mutations serialized, but run snapshots in a second `Process` worker (they are read-only), or let snapshots go ahead of a waiting mutation. In `execute`, map pkexec exit status 126 and timedated's `Access denied` after a prompt to "Authentication was cancelled", shown as a neutral notice.

### 8. Text at 150% overflows the sidebar (Low, confidence high)

`modules/Settings.qml:92,104,118`. Navigation rows have a fixed 36 px height and section headers a fixed 26 px. At 150% text in the minimum 820×540 window, the section labels touch the rows, "Accounts & calendars" is truncated, and the footer "Changes save automatically" has no `Layout.fillWidth`/elide. Its width pushes the sidebar column past the 244 px divider, so the search field and selection pill reach the edge (screenshots `min-accessibility` and `min-power`). The embedded control-center Wi-Fi list is also crowded at 150% (`min-network`). Page content cards and dropdowns handle the scaling well.

Smallest fix: `height: Math.max(36, label.implicitHeight + 16)` for rows and a scaled section header height. Give the footer label `Layout.fillWidth: true; elide: Text.ElideRight` (or wrap it).

### 9. Storage offers Eject for empty removable devices; Empty Trash is enabled with nothing to empty (Low)

`modules/settings/StoragePage.qml:50`. The VM's `/dev/fd0` (removable, size 0, no media) appears under Volumes with an **Eject** button (screenshot `storage`). The Framework equivalent is an empty card-reader or expansion-card slot. Filter out drives with `sizeGiB === 0`, and disable **Empty…** when `trashCount === 0`.

### 10. VM-specific text is shown on the laptop (Low)

`modules/settings/PowerPage.qml:56` shows "Keep this off for reliable remote access to the VM." on every host. Gate it on `Prefs.system.fixedDisplayMode`, or add a host flag as `UpdatesPage` already does with `systemEnabled`.

### 11. Resolution list repeats the current mode in a different format (Low)

`modules/settings/DisplayPage.qml:26,29`. The current mode is formatted with `toFixed(5)` (`1440x960@74.99500`), while `availableModes` uses two decimals (`1440x960@75.00`). The `Set` therefore keeps both, and the raw five-decimal string appears in the UI. The control is disabled on the VM. It will show on the Framework. Normalise to two decimals for display and keep the exact value for the request.

### 12. Leftover duplicate default-browser path (Low, maintainability)

`modules/Settings.qml:34` (`browsers`, unused), `services/Prefs.qml:40,90` (`setBrowser`), `nixos/modules/home/settings/settings.py:331,364-369` (`browser` action using `xdg-settings`). Default apps now uses GIO through `admin.py`. Remove the old path so the default browser has a single owner.

## Untested risks

- **Tailscale toggle probably fails once the device is signed in** (medium likelihood, not reproduced because the VM is in `NeedsLogin`). `admin.py:378` runs `tailscale up --timeout=5s`. Passing any flag takes `tailscale up` off its plain re-up path and into the check for accidentally reverted settings. `--operator` is set to a non-default value through `extraSetFlags` (`nixos/modules/nixos/base.nix:28`), and recent `tailscale` versions then refuse with "requires mentioning all non-default flags". Fix: run bare `tailscale up` and rely on the subprocess `timeout=10`. Verify on a signed-in machine.
- **`flatpak search` on a cold appstream cache** can exceed 60 s on slow networks. That holds the queue (finding 7) and then reports a raw `TimeoutExpired` message.
- **Physical hardware**, as stated in `SETTINGS.md`: backlight, touchpad, battery, removable media, Bluetooth pairing, USB printers and live online accounts remain unverified. The Framework storage layout (LUKS → btrfs subvolumes with `/`, `/home`, `/nix`, `/swap`) should be protected correctly by the ancestor rule in `block_devices`, but I only checked this by reading the code.

## Design and usability

What works: the visual language is consistent with the stated preferences. Surfaces are dark, neutral and slightly translucent. Hover is gray, selection is solid blue, focus rings are visible, and nothing bounces. Pages are short, and grouping the sidebar into Personal, Devices, Connections and System is clear. Keyboard navigation works: Ctrl+F reaches search, Tab moves into the list, arrows change page, and Tab moves into the page controls with visible focus rings. Delegated tools are labelled honestly ("Open Disks…", "Open editor…"). Destructive actions (Empty Trash, Reset, Remove printer, session actions) have inline confirmations.

Recommendations, in order of value:

1. **Show confirmations and results next to the control that triggered them.** Findings 3 and 7 are both cases of feedback appearing far from where the user acted. Since the error label sits in the page header, also scroll to it or briefly highlight the row that failed.
2. **Style the PolicyKit dialog.** hyprpolkitagent opens a light, unthemed window titled "Authenticating for unix-user:reagan" (screenshot `polkit`). Every printer, time-zone and system-update action goes through it. Give it the same dark Qt platform theme the shell uses (hyprpolkitagent supports the hyprqt6engine platform theme).
3. **Merge the two Flathub rows** in Applications. "Search Flathub" with a text field and "Find applications" with a separate, usually disabled Search button can be one entry with a trailing button. Pressing Enter already searches.
4. **Startup apps** lists every installed app as a toggle. GNOME and KDE show the enabled entries plus an "Add" picker, which scales better and makes the current state readable at a glance.
5. **Bluetooth forget** is only available by right-click (`BluetoothPage.qml:17` explains this in text). Add a visible "Forget…" action on saved devices for keyboard and touchpad users.
6. Minor points:
   - Time zone shows "Choose…" while a search excludes the current zone. Pin the current zone at the top.
   - Notification "Clear history" has no confirmation, while clipboard clear does.
   - The Input page fallback for `focusFollowsMouse` is `false` while the schema default is now `true` (`InputPage.qml:104` vs `settings.py:45`). Values are always loaded, so this is cosmetic, but keep them consistent.

## Functionality and stability

- **Privilege and validation boundaries are strong.**
  - Every action rejects unknown fields.
  - IDs are regex-checked and confirmed against current state: installed apps, owned print jobs, listed VPN UUIDs, and system time zones.
  - Printer URIs are restricted to ipp/ipps without credentials.
  - There is no generic command endpoint, `pkexec` only runs fixed binaries, and the admin tests check most of this.
  - The new `settings operation` IPC adds no privilege, since any same-user process could already run `desktop-admin`.
- **Persistence and rollback:** preference saves roll back live Hyprland/GTK state on failure, and the display preview watchdog is preserved. Time-zone persistence through mutable `/etc/localtime` works, and the bar clock follows a live change. The weak point is reporting failure in the UI (findings 1 and 2), not the backend.
- **Async and concurrency:**
  - Shared Wi-Fi scan and Bluetooth discovery ownership is correct, and the test covers it.
  - Background Flatpak jobs survive closing Settings.
  - Polling runs only while its page is open, but the Updates page starts a Python process plus 3–5 `systemctl` calls every 3 s for as long as it is visible. Polling at 10 s, or only while a job is active, would be cheaper on battery.
- **Startup apps** run once per Hyprland instance through a marker in `XDG_RUNTIME_DIR`, and terminal apps open in Ghostty through `AppLaunch`. Because the marker is created before the launches, a failure partway through is not retried. That is acceptable.
- **Clipboard selection:** `ClipboardSelection.qml` correctly follows the newest entry until the user navigates, and the Qt Quick test covers it. When the selected entry is deleted, the selection jumps to the newest entry rather than a neighbour. That is a minor UX point, not a bug.

## Test blind spots

- No test covers a failed operation's path through the QML services (findings 1 and 2). `settings_ui.py` only asserts that pages load without errors.
- No check covers layout at minimum size or enlarged text. Even one screenshot check at 820×540 and 150% would have caught finding 8.
- Default-app candidate correctness and the `default-app` MIME capability are untested (finding 5).
- Failed or cancelled background job presentation and cleanup are untested (finding 4).
- The Tailscale and VPN commands are only tested through mocked argv, not against CLI semantics.
- No test checks that `SettingsAdmin` snapshots keep running while a mutation waits for authentication (finding 7).

## Maintainability

The split is maintainable for one person. Each page is 25–220 lines, the shared row components keep visual decisions in one place, the catalog is data, and `admin.py` (≈400 lines) gives every operation a short validated block. I don't recommend a framework or a plugin system. Three targeted changes would keep it from drifting:

1. Give state-reflecting controls a single source of truth (finding 2). This is a component-level fix that every future page benefits from.
2. When `admin.py` grows past about 25 actions, replace the `perform` if-chain with a small `{action: handler}` table. It is fine as is.
3. Remove the legacy browser path (finding 12) and keep `SETTINGS.md`'s ownership list as the place to check before adding controls.

## Remaining coverage compared with GNOME and KDE

Beyond the documented exclusions (screen reader, magnifier, users, fingerprint, colour management, per-app notification rules, shortcut editing), these are the gaps most relevant to the Framework that are practical to add:

- **Firmware updates (fwupd/LVFS).** Framework ships BIOS and EC updates through LVFS. Both GNOME Software and KDE Discover show them. `services.fwupd.enable` plus status and update actions in Updates would fit the existing fixed-job pattern.
- **Night light / colour temperature** (hyprsunset or gammastep) is a standard GNOME/KDE display feature and easy to add as a preference.
- **Battery charge limit and lid-close behaviour** (logind `HandleLidSwitch`, the Framework EC charge limit), on the Power page.
- **Language, regional formats and input methods** are currently read-only "managed by the system configuration". That matches the Nix ownership model, but differs from GNOME/KDE.
- **Sharing and remote desktop, location services, and the About page's hardware model, CPU and GPU** are absent. They matter less.

Screenshots referenced above were saved in the reviewer's scratch directory for this session and are not part of the repository.
