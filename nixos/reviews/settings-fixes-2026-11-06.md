# Settings fixes: 2026-11-06

Status of the findings in `settings-review-2026-11-06.md` (the "first review") and `settings-review-2026-11-06-edge-cases.md` (the "edge-case review"). Both reports are kept unchanged as the historical record. Base commit: `7e2ac10`. Nothing was committed or pushed.

## Summary

All numbered findings in both reviews are fixed, as are the Tailscale and `flatpak search` timeout risks. Three more defects turned up during verification and were fixed:

- A filtered dropdown could show a value that was not stored.
- Entry fields threw a binding error.
- Slider values were cut off at 150 % text.

GNOME/KDE feature gaps and the optional design recommendations are deferred. Hardware behaviour is still unverified.

## Findings

| Finding | Status | Change | Evidence |
| --- | --- | --- | --- |
| Edge 1: a failed save can leave live and saved settings inconsistent | Fixed | `settings.py` stages all generated files, applies the live changes, then writes the files in order. If any step fails, it restores the files already written (and removes new ones), then runs every live undo. Each recovery step runs on its own, so one failed undo doesn't skip the others. If recovery itself fails, the error says so. hypridle restarts only after a successful save. | `tests/settings.py` injects a failure at every write and live-apply step, then checks the files and live state (`test_each_write_failure_restores_files_and_live_state`, `test_failed_first_save_removes_new_files`, `test_rollbacks_are_independent_and_incomplete_recovery_is_reported`, `test_failed_file_restore_is_reported`, `test_keep_display_failure_restores_monitor_choices`). Nine of these tests failed before the fix. |
| Edge risk: one failing rollback skips the next | Fixed | As above. | `test_rollbacks_are_independent_and_incomplete_recovery_is_reported` |
| Edge risk: a disconnected preview output blocks clearing the recovery record | Fixed | `revert_display` verifies the old rule only for outputs that are still connected. It always clears the pending record. | `test_disconnected_preview_output_still_clears_recovery_record` |
| Edge risk: malformed state file | Fixed (policy) | The file is kept and not overwritten. The error names the file and says it was not changed. There is no automatic destructive recovery. | `test_malformed_state_names_the_file_and_is_kept` |
| Edge 2: a `TERMINAL` value with arguments breaks terminal apps | Fixed | `AppLaunch.terminalCommand` uses `$TERMINAL` only when it is one executable name or path (no spaces, no leading `-`). It runs `TERMINAL -e PROGRAM ARGS…` and otherwise falls back to Ghostty. The contract is documented in `SETTINGS.md`. | `settingsFailures` harness: four `terminalCommand` cases |
| 1: failed preference saves are silently cleared | Fixed | `Prefs.qml` records which action set the error. A resync clears only errors from an earlier `get`. | `settingsFailures`: "failed save error survives the resync" (went red when the fix was reverted) |
| 2: switches show unaccepted state | Fixed | `SettingToggle` is no longer checkable. It shows the owner's value and asks for the change on click. `SettingChoice` rebinds `currentIndex` after `activated` and after model changes. A failed admin change still refreshes its sections. | `settingsFailures`: preference, refused, admin and dropdown checks, each red with its fix reverted. Native: after a cancelled time-zone change, the dropdown shows America/New_York again. |
| 3: Remove confirmation and permission details appear off-screen | Fixed | The confirmation, permissions and reset confirmation now open inside the app's own row in `AppsPage.qml`. | `settingsFailures`: confirmation and permissions appear only in the chosen app's row (red when the confirmation is not tied to its row). Natively, permissions for the system Zen app are verified. The VM has no user-scope Flatpak, so the native Remove flow could not be exercised. |
| 4: failed background jobs show an anonymous permanent banner | Fixed | `admin.py` lists each install/remove job with its operation, app and state. For a failed job it adds the last output of that job's latest run. The page shows "Couldn’t remove NAME", the excerpt, the `journalctl` command, and Retry/Dismiss buttons. Dismiss runs `systemctl --user reset-failed` only for a validated, listed, failed job unit. | `test_failed_jobs_are_attributed_and_bounded`, `test_failed_job_log_falls_back_to_systemd_lines`, `test_dismiss_only_resets_listed_failed_jobs`. Native: a failed `desktop-flatpak-remove@org.example.ReviewFixture` job showed flatpak's own error. Retry re-ran validation ("Only applications added for your account can be removed here"). Dismiss removed the row and reset the unit. |
| 5: Default apps offers apps that can't open the type | Fixed | Candidates come from `Gio.AppInfo.get_all_for_type`. For text only, apps in the TextEditor category are added too, because VSCodium declares no MIME types. The current handler is always shown. `default-app` rejects apps that don't declare the type and sets related types only when the app declares them. The legacy `xdg-settings` browser path was removed. | `test_default_app_must_declare_the_type`, `test_text_editor_category_is_the_only_category_fallback`, `test_default_candidates_come_from_mime_support_and_keep_current`. Native: browser, PDF and mail list Zen; files lists Files; text lists VSCodium. Audio and video show "No installed application opens this type". |
| 6: Updates reports success for jobs that never ran | Fixed | It now shows "Not run since startup" when there is no timestamp and reports failed runs with their result. The poll interval is 3 s while a job runs and 15 s otherwise. | Native: Updates shows "Not run since startup" |
| 7: one admin queue is held by authentication prompts and searches | Fixed | `SettingsAdmin.qml` has two lanes. Snapshots and permission details run in one. Changes and Flathub searches run in the other. A cancelled PolicyKit prompt (pkexec 126, timedated "Access denied") is shown as a neutral notice. | `test_cancelled_authentication_is_distinguished_from_denial`. `settingsFailures`: a storage snapshot completes while a slow change is pending, and the cancellation notice is neutral. Native: with the time-zone prompt open and the footer showing "Applying…", Storage and Appearance loaded. Cancelling showed "Authentication was cancelled or not completed. Nothing was changed." in dim text, and the zone was unchanged. |
| 8: text at 150 % overflows the sidebar | Fixed | Sidebar width, section headers and nav rows scale with text. Footer labels fill their width. Two related defects found at 150 % were also fixed: `SettingEntry` referred to a missing `contentItem` (a binding error, so the field never grew), and slider values were cut to "100…". | Native at 820×540 with 150 % text: Applications (including a failed job row), Default apps, Displays, Storage and Updates. No clipped sidebar text. |
| 9: Eject shown for empty drives; Empty Trash enabled with nothing to empty | Fixed | Drives with size 0 are hidden. Empty Trash is disabled at 0 items ("Your home Trash is empty."), and its confirmation requires items to remove. | Native: no fd0 row; Empty Trash disabled |
| 10: VM text shown on the laptop | Fixed | The Power text that only applies to the VM depends on `fixedDisplayMode`. | Framework toplevel builds. Not viewed on the laptop. |
| 11: resolution list repeats the current mode | Fixed | Modes are deduplicated by size and refresh rate within 0.05 Hz and shown as "W × H · R.RR Hz". The exact mode string is still what gets sent. | Native Displays page |
| 12: duplicate default-browser path | Fixed | `browser` was removed from `settings.py`, `Prefs.qml` and `Settings.qml`, and `xdg-utils` from the helper inputs. | Tests and builds pass |
| Risk: Tailscale toggle fails once signed in | Fixed (from source) | It now runs bare `tailscale up` with a 15 s timeout. A timeout while enabling reports "Tailscale is still connecting." In the pinned 1.104.4 source, `--timeout` counts as a set flag, so `up` checked for reverted settings and rejected the operator setting. | `test_tailscale_reconnects_with_bare_up`. Not run against a signed-in node. |
| Risk: `flatpak search` timeout shows a raw error | Fixed | Searches no longer block snapshots. A timeout reads "The operation took too long and was stopped. Try again later." Failed requests return the sections to refresh. | `test_failed_requests_report_sections_to_refresh` |
| Blind spots: QML failure paths, minimum layout, defaults, jobs, concurrency | Covered | New `checks.settingsFailures` runs the production Settings services and controls headless (offscreen Quickshell) against fake helpers. It is wired into `.github/workflows/nixos-check.yml`. | 27 checks pass. Each fix was reverted in turn to confirm its check fails. |

Also found and fixed during verification: when a search hid the stored value, the time-zone dropdown showed the first match as selected. Qt's ComboBox resets `currentIndex` when its model changes, which also broke the binding for good. `SettingChoice` now rebinds after model changes. The `settingsFailures` check for this failed before the fix and passes after it. On the final VM, searching "London" now shows "Choose…" while the stored zone stays America/New_York.

## Deferred

- First-review design recommendations 2–5: PolicyKit dialog theming (still a light, unthemed window), merging the two Flathub rows, an Add picker for Startup apps, and a visible Bluetooth Forget action. These are improvements, not defects.
- The GNOME/KDE coverage list (fwupd, night light, charge limit, language and regional settings, sharing) was excluded by request.
- At 150 % text, a closed dropdown elides long values such as "1440 × 960 · 75.0…". The open menu widens to show them in full.
- The cancellation notice stays visible on whichever page is open until the next change or page switch.
- The `perform` handler table in `admin.py`, recommended once it passes about 25 actions.

## Limits

- Each file is written atomically by a rename. A crash or power loss between two renames can still leave files from different saves. The fix covers errors that Python sees, not a cross-file crash.
- The fault injection uses mocked writes, `hyprctl` and GTK calls. There was no real disk-full or compositor crash.
- Laptop hardware (backlight, touchpad, battery, removable media, Bluetooth pairing, printing) and live accounts remain unverified, as `SETTINGS.md` states.
- The Tailscale fix follows the CLI source and the mocked argv. The VM is in `NeedsLogin`.
- The native Remove confirmation needs a user-scope Flatpak; it is covered by the headless harness only.

## Checks run

- `nix build .#checks.x86_64-linux.{settings,admin,settingsFailures,dropdowns,clipboardSelection,calendar}`: all pass. Preferences: 21 tests. Admin: 30 tests. Harness: 27 checks.
- `nixosConfigurations.vm.config.system.build.vm` and `nixosConfigurations.framework.config.system.build.toplevel` both build.
- In the VM (KVM, final runner), `nixos/tests/settings_ui.py` (all 19 pages and scanner ownership) and `nixos/tests/control_center.py` pass.
- Native VNC checks: Applications job failure, Retry and Dismiss; inline permissions; Default apps; Updates; Storage; Displays; 820×540 at 150 % text; a PolicyKit prompt held open while other pages load; cancellation.

Fixtures and personal state: the simulated Wi-Fi networks, the virtual Bluetooth headphones and the silent audio device are unchanged. The text scale went back to 100 %, the window to 960×680, Caffeine to off, and the failed fixture job was reset.

### Final verification correction

The parent found one remaining recovery gap in the subagent's transaction: reading the previous file contents happened outside the recovery block, after live changes were applied. A permission or read error there skipped every live undo. `test_backup_read_failure_restores_live_state_without_writing` reproduced this for all three artifacts before the correction. Backup reads now run inside the recovery block. All 21 preference tests pass, including checks that the original files stay untouched and both appearance and compositor state are restored. Both host builds and the six flake checks were repeated successfully after this correction.

The final runner was then booted under KVM. The parent verified that `/run/current-system` matches the built runner, repeated both native suites successfully, and left Settings open with Caffeine off. The failure-state check also runs in the automatic dependency-update workflow, before it can publish an updated lock file.
