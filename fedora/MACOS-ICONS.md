# Light macOS app icons

The Niri profile selects `Graphite-macOS-Light`, a user icon theme populated from [macOSicons.com](https://macosicons.com/) and the official T3 Code artwork. App icons use the site's original light variants; the shell and GTK surfaces remain dark.

The installed theme is at `~/.local/share/icons/Graphite-macOS-Light/`. Its `SOURCES.md` credits each artist and links to the source artwork. The community [manifest](roles/niri/vars/macos-icons.yml) records the icon names, creator/profile links, original download URLs, source SHA-256 checksums and extracted PNG checksums. The [official icon manifest](roles/niri/vars/official-icons.yml) separately pins the T3 Code Nightly macOS PNG and its full license notice. No icon bitmaps are bundled in this repository. Each machine downloads its own copies.

The [site terms](https://macosicons.com/terms) allow personal customization. Icons remain their creators' property; preserve attribution and any icon-specific license. Do not resell or repackage the selection as your own artwork or an icon-library product. See also the [API terms](https://macosicons.com/developers/terms).

## Coverage

The live launcher inventory includes Ghostty, Zen, VSCodium, btop, Files, Calendar, Disks, Passwords and Keys, Volume Control, Print Settings, Online Accounts and T3 Code. Each has a selected light icon. Both Volume Control icon names are covered, as are the Settings and Noctalia aliases for settings entries that may be available in other sessions.

The selection includes these substitutes and official sources:

| App | Source artwork |
| --- | --- |
| btop | Activity Monitor |
| Files | Finder |
| Disks | Disk Utility |
| Passwords and Keys | Apple Passwords |
| Volume Control | Sound Control |
| Print Settings | HP Print, a generic blue printer drawing without brand text |
| Online Accounts | Account/profile shield without brand text |
| T3 Code | Official T3 Code Nightly macOS artwork, used directly rather than a substitute |

Zen uses the exact user-selected [Zen iOS Default Light icon by inkyyuki](https://macosicons.com/?icon=0AeL19Hq0J), object `0AeL19Hq0J`. The official T3 Nightly icon is pinned to upstream commit `83a3674ffd84ffb33de768210c806cb1ac53fd80`; its PNG is downloaded unchanged and its MIT notice is installed as `t3code-LICENSE.txt`. This selects the requested artwork independently of the installed application's release channel.

The app labels, launch commands and file/URI associations do not change. T3 Code uses its selected PNG through an optional icon override in the shared app task; the GNOME profile's default desktop entry remains identical.

The theme inherits Papirus-Dark, Adwaita and hicolor for folders, status symbols and apps installed later. Add a manifest entry when adding a new launcher app. Papirus-Dark is a fallback, not a substitute for covering the currently configured app list.

## Installation and updates

`roles/niri/tasks/icons.yml` downloads each unique original Mac icon file with a pinned checksum. The standard-library-only `icns-to-png.py` tool extracts its largest embedded PNG without resizing, recoloring or re-encoding it. All selected assets contain native 1024×1024 PNGs. Official PNG assets bypass the ICNS extractor and are installed directly by checksum-pinned downloads. The tool runs only during provisioning, not at login or in the background. No Mac-specific tools, Pillow dependency or Noctalia plugin is required.

Extracted files are written atomically and only when their bytes change. The theme index is published after all assets are ready, then dconf selects the theme. Noctalia and Fuzzel use the same icon theme. Original downloads are retained in the theme's `.sources/` directory so unchanged reruns need no download or image conversion.

To replace an icon, update its manifest entry, including both checksums and creator credits, then rerun `niri.yml`. Use an existing Linux icon name or update the corresponding desktop-entry icon reference. Do not overwrite package-owned desktop files. The normal run checks that the selected and fallback themes exist; those post-install presence assertions are skipped in check mode because a fresh dry run has not created the predicted files.

The earlier experimental `Graphite-macOS` dark theme may remain on a machine that tested it. It is inactive. No existing icon themes or personal files are removed.

## Verification

Opus 5.5 medium approved the light set in actual launcher and dock captures. A live audit resolves all 12 visible launcher apps to their selected theme files and verifies native 1024×1024 dimensions and PNG checksums. All community and official aliases resolve, and folders retain their Papirus-Dark fallback. The extraction and existing Fedora unit tests all pass, and the shared GNOME desktop entry remains unchanged when no T3 icon override is supplied. The full provisioning rerun and `--check --diff` both report zero changes. See the [review record](reviews/niri-macos-icons.md).
