# Custom icons

Images here replace icons from the base theme (`desktop.theme.icons`, Papirus by default) for apps, the dock, the launcher and Files. Anything without an image here still comes from the base theme.

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

New files must be added to git (`git add`) before a rebuild sees them. Then rebuild; the dock and launcher pick the change up after `hyprctl reload` or a new login.
