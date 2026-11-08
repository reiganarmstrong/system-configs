# Custom icons

Images here replace icons from the base theme (`desktop.theme.icons`, Papirus by default) for apps, the dock, the launcher and Files. The pinned Graphite macOS Light app theme sits between these overrides and Papirus-Dark. Anything without a matching app image falls back to Papirus-Dark.

Name each file after the icon it replaces, as an `.svg` or `.png` (square, 256 px or larger):

| Folder | Holds | Example |
| --- | --- | --- |
| `apps/` | App icons | `apps/com.mitchellh.ghostty.svg` |
| `places/` | Folders | `places/folder.svg`, `places/folder-download.png`, `places/user-home.svg` |
| `mimetypes/` | File types | `mimetypes/application-pdf.svg`, `mimetypes/text-x-python.svg` |

New folders work too; every folder here is read.

To find an app's icon name, read the `Icon=` line of its desktop entry:

```sh
grep -h '^Icon=' $(find ~/.nix-profile/share/applications /run/current-system/sw/share/applications /var/lib/flatpak/exports/share/applications -name '*.desktop') | sort -u
```

New files must be added to git (`git add`) before a rebuild sees them. Then rebuild; the dock and launcher pick the change up after a new login.

## Pinned Graphite artwork

`macos-sources.json` preserves the Fedora profile's exact URLs, authors and SHA-256 hashes. `macos.nix` fetches those files, extracts their original 1024 px PNGs with `extract-icns.py`, and checks the extracted bytes before publishing the theme. The original files are not resampled. T3 Code uses the official Nightly artwork from a pinned upstream commit, with its MIT notice preserved; its installed release channel is unchanged. Settings uses the same System Settings icon under `preferences-system`.

Apps with no macOS counterpart use a light icon that fits their job: Bluetooth File Exchange for Blueman (`blueman`, `blueman-device`), AirPort Utility for Advanced Network Configuration, iDisplay for Displays, Print for Manage Printing (`cups`), ClipBoard for Clipboard history and Books for the NixOS Manual. The last two are this repo's own desktop entries, so they use their own icon names (`clipboard-history`, `nixos-manual`) rather than replacing the shared `edit-paste` and `nix-snowflake` icons. To cover a new app, add an entry with the icon file's URL and both checksums.

The macOSicons artwork is for personal desktop customization. Each icon remains its creator's property, and the brands retain their trademarks. Source pages and creator links accompany the installed theme in `SOURCES.json`.
