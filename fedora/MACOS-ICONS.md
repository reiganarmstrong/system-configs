# Light macOS app icons

The Niri profile selects `Graphite-macOS-Light`, a user icon theme populated from [macOSicons.com](https://macosicons.com/). App icons use the site's original light variants; the shell and GTK surfaces remain dark.

The installed theme is at `~/.local/share/icons/Graphite-macOS-Light/`. Its `SOURCES.md` credits each artist and links to the source artwork. The authoritative [manifest](roles/niri/vars/macos-icons.yml) records the icon names, creator/profile links, original download URLs, source SHA-256 checksums and extracted PNG checksums. No third-party icon images are bundled in this repository. Each machine downloads its own personal-use copies.

The [site terms](https://macosicons.com/terms) allow personal customization. Icons remain their creators' property; preserve attribution and any icon-specific license. Do not resell or repackage the selection as your own artwork or an icon-library product. See also the [API terms](https://macosicons.com/developers/terms).

## Coverage

The live launcher inventory includes Ghostty, Zen, VSCodium, btop, Files, Calendar, Disks, Passwords and Keys, Volume Control, Print Settings, Online Accounts and T3 Code. Each has a selected light icon. Both Volume Control icon names are covered, as are the Settings and Noctalia aliases for settings entries that may be available in other sessions.

Where the exact application was unavailable, the selection uses an appropriate substitute:

| App | Source artwork |
| --- | --- |
| btop | Activity Monitor |
| Files | Finder |
| Disks | Disk Utility |
| Passwords and Keys | Apple Passwords |
| Volume Control | Sound Control |
| Print Settings | HP Print, a generic blue printer drawing without brand text |
| Online Accounts | Account/profile shield without brand text |
| T3 Code | Light Script Editor |

The app labels, launch commands and file/URI associations do not change. T3 Code uses its selected PNG through an optional icon override in the shared app task; the GNOME profile's default desktop entry remains identical.

The theme inherits Papirus-Dark, Adwaita and hicolor for folders, status symbols and apps installed later. Add a manifest entry when adding a new launcher app. Papirus-Dark is a fallback, not a substitute for covering the currently configured app list.

## Installation and updates

`roles/niri/tasks/icons.yml` downloads each unique original Mac icon file with a pinned checksum. The standard-library-only `icns-to-png.py` tool extracts its largest embedded PNG without resizing, recoloring or re-encoding it. All selected assets contain native 1024×1024 PNGs. The tool runs only during provisioning, not at login or in the background. No Mac-specific tools, Pillow dependency or Noctalia plugin is required.

Extracted files are written atomically and only when their bytes change. The theme index is published after all assets are ready, then dconf selects the theme. Noctalia observes theme changes and refreshes its icons. Original downloads are retained in the theme's `.sources/` directory so unchanged reruns need no download or image conversion.

To replace an icon, update its manifest entry, including both checksums and creator credits, then rerun `niri.yml`. Use an existing Linux icon name or update the corresponding desktop-entry icon reference. Do not overwrite package-owned desktop files. The normal run checks that the selected and fallback themes exist; those post-install presence assertions are skipped in check mode because a fresh dry run has not created the predicted files.

The earlier experimental `Graphite-macOS` dark theme may remain on a machine that tested it. It is inactive. No existing icon themes or personal files are removed.

## Verification

Opus 5.5 medium approved the light set in actual launcher and dock captures. A live audit resolves all 12 visible launcher apps to their selected theme files and verifies native 1024×1024 dimensions and PNG checksums. All 15 aliases resolve, and folders retain their Papirus-Dark fallback. The extraction and existing Fedora unit tests all pass, and the shared GNOME desktop entry remains unchanged when no T3 icon override is supplied. The full provisioning rerun and `--check --diff` both report zero changes. See the [review record](reviews/niri-macos-icons.md).
