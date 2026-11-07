# Joined menus, glass app search and Framework readiness

Implemented and checked on November 7, 2026, in the Fedora 45 Niri VM. Opus 5.5 at medium effort designed the joined menus and Fuzzel styling, and reviewed actual joined-menu and requested-icon captures. Codex implemented the profile, checked the final glass rendering and runtime behavior, and reviewed the hardware and authentication changes. Separate Codex reviews found and helped fix the Tailscale dry-run cases; the final review found no blocking issues.

## Appearance and app search

The user chose native Noctalia attached menus with the bar on Overlay, including above fullscreen apps. Control center, wallpaper and session panels share the solid black bar's fill and concave join. Clipboard history and polkit stay centered and floating. The fullscreen bar covers the top 34 logical pixels by design. No custom panel code, plugin, CSS or layer-switching script is installed.

The user chose Fuzzel for independently themed app search, then requested dark glass. Its native configuration uses `18181ad6` for the background, `2e2e31e6` for the selection and light text, with an unboxed prompt. A Niri rule matches only `graphite-app-launcher`, enables non-xray blur and sets a 16 px geometry radius matching the client. Noctalia's shared colors remain intact. Fuzzel follows the existing icon theme and desktop visibility rules, and launches terminal apps through `xdg-terminal-exec`.

Super+Space toggles only the current user's exact named launcher command. Other Noctalia shortcuts remain. The dock's built-in Noctalia launcher button is hidden. The user accepted that app search no longer supplies Noctalia's calculator, emoji, `/` providers, pinned-first ordering or icon grid.

The global initial column width is now `proportion 1.0`; presets are `0.5`, `0.66667`, `1.0`. Super+R remains `switch-preset-column-width`. The live test observed a successful automatic ConfigLoaded event, an existing 1705 px column retaining its width, a new 1896 px column on the 1920 px output, and actual Super+R cycling 942, 1260 and 1896 px. Opening the new app did not resize existing columns. The 12 px gaps and existing per-app width rules remain.

## Exact icons

Zen uses the requested macOSicons object `0AeL19Hq0J`, by inkyyuki. T3 Code uses the official Nightly macOS PNG pinned to upstream commit `83a3674ffd84ffb33de768210c806cb1ac53fd80`. This replaces the Script Editor stand-in without changing the installed app's channel. The official PNG bypasses ICNS extraction; its full MIT notice is installed alongside the theme. Community sources, original checksums and attribution remain in the separate community manifest.

The live icon audit verified all 12 launcher apps and all 15 aliases, with native 1024×1024 dimensions and matching PNG checksums. Papirus-Dark remains the folder/future-app fallback. Actual Fuzzel and dock captures show the new Zen and T3 icons.

## Hardware and authentication

The role now explicitly installs Fedora's stock kernel/common modules, Intel Wi-Fi/Bluetooth/GPU/audio firmware, SOF firmware, ALSA routing profiles, CPU microcode, libcamera backend, fwupd and fingerprint packages. This fills gaps in minimal installs where weak dependencies are disabled. The running VM kernel was not replaced by a reboot; the new kernel takes effect after a future reboot.

Fingerprint setup validates the current authselect policy and feature support before mutation, uses a native backup, enables only `with-fingerprint`, and verifies preservation of the prior profile/features. The VM retained `local with-silent-lastlog` and added `with-fingerprint`. An explicit opt-out leaves PAM policy alone. Enrollment is never automated. Noctalia already supports fprintd directly. Password login remains available and is needed for automatic oo7 keyring unlocking at initial login.

Tailscale uses its signed official repository, an enabled running daemon and the desktop account as operator. Guards handle a dry run with no CLI/unit installed and a predicted service start when the daemon is stopped. A real first-install dry run passed without installing the client. A stopped-daemon dry run passed without starting it, and the original running state was restored. A separate running-service dry run reported no changes.

The guest stays in NeedsLogin. Before first authentication, operator preferences can be temporary, so FRAMEWORK.md gives the one-time browser sign-in followed by `sudo tailscale set --operator="$USER"` on the saved profile. No login, auth key, routing reset, firmware flash, reboot or biometric enrollment was performed by automation.

## Verification

- `niri validate`, `noctalia config validate` and `fuzzel --check-config` pass. The Fuzzel keys were checked against the installed 1.15.0 manual.
- All 93 bindings pass the checker against 118 installed Noctalia commands. All 13 Fedora unit tests pass.
- Fuzzel opens, toggles closed and closes on Escape. Typing and Enter launch Disks; a terminal-app search launches btop in Ghostty. Desktop filtering removes GNOME-only Settings from this session's app list.
- Launcher/menu captures at scales 1, 1.25 and 1.5 fit the output. Final glass-corner probes at scales 1 and 1.5 leave all 128 and 344 sampled pixels outside the rounded corners unchanged. Background checker contrast drops from about 97 to 5.9/5.3 through the panel, confirming blur beyond the tint alone.
- Clock/status/session clicks, native reduced motion, fullscreen visibility, Escape dismissal and focus restoration pass. The final dock has the requested icons and no duplicate launcher button. Temporary overrides, probes and test windows were removed; scale 1 was restored.
- Mocked native authselect probes cover missing current profile, invalid policy, unsupported feature and opt-out. No mutation was attempted in these cases, and the real policy remained unchanged.
- Final normal Ansible rerun reports `ok=102 changed=0 failed=0`; final `--check --diff` reports `ok=93 changed=0 failed=0`.

The final configuration, manifests and install guidance are tracked in the Ansible profile. Captures, test probes, downloaded research assets and VM credentials remain ignored. No changes were applied to the host or physical laptop, and nothing was pushed.

Physical fingerprint matching, firmware application, Wi-Fi, Bluetooth, audio, camera, brightness, docks, expansion cards and suspend/resume still need testing on the actual laptop. [FRAMEWORK.md](../FRAMEWORK.md) gives those steps and the official model-specific sources. Installing drivers is not proof that every peripheral operates.
