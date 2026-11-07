# Light macOS icons review

The user requested macOSicons.com assets, then specified light-mode icons and coverage for every launcher app, allowing suitable substitutes where an exact app was unavailable. Opus 5.5 at medium effort selected the light set and separately approved actual launcher and dock captures. The final theme is `Graphite-macOS-Light`; the shell, app names, launch commands and wallpaper remain unchanged.

All 12 currently visible launcher entries use selected native 1024×1024 PNGs. The audit used Noctalia's session data directories, including the Flatpak exports for Zen. It resolved every app through GTK, checked the resulting theme path, verified the PNG checksum and dimensions, and handled T3 Code's direct-file icon reference separately. All 15 manifest names resolve correctly, including both sound aliases and the optional Settings entries. Folder icons continue to resolve through Papirus-Dark.

Substitutes are documented in MACOS-ICONS.md. T3 Code uses the light Script Editor image; Online Accounts uses an account/profile shield. The visual reviewer confirmed the substitutes fit their apps, the white/cream/silver tiles have consistent padding, and the small launcher icons are legible. The original black T3 icon is replaced in the dock.

The role downloads checksum-pinned original Mac icon files and extracts their embedded PNG bytes without resizing, recoloring or re-encoding. Source images are not redistributed in this repository. The manifest and installed `SOURCES.md` preserve creator credits, source links and checksums.

## Code review and verification

A separate Codex review found one check-mode defect: post-install presence assertions treated a predicted new theme as missing during a first-install dry run. Both theme-presence assertions now run only outside check mode; normal provisioning still requires the selected and fallback themes to exist.

The extraction tool's tests cover native-image selection, ignored metadata, malformed/truncated records, unchanged-file timestamps, atomic permissions and preservation of an existing icon on failure. All 13 Fedora unit tests pass. The shared T3 desktop template renders identically to the previous GNOME version when its optional icon override is absent.

The light-theme install passed with `ok=78 changed=8 failed=0`. A later tool update was deployed successfully, and the final unchanged rerun reports `ok=78 changed=0 failed=0`. The final `--check --diff` run reports `ok=74 changed=0 failed=0`. Runtime Noctalia validation reports zero warnings. Captures and detailed review reports remain in ignored `fedora/.local/niri-vm/`; temporary dock-preview settings were removed and auto-hide restored.
