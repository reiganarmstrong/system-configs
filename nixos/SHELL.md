# Working on the shell

Everything you see on the desktop that isn't an app window is one Quickshell config: the bar, the dock, the control centre and its pages, the Wi-Fi, Bluetooth and Sound menus, the clipboard menu, the launcher, notifications, the volume and brightness pop-ups, and the lock screen. Quickshell runs QML files, the same language Qt apps use for their interfaces. This guide covers where those files are, how they reach the running desktop, and how to change them without rebuilding the whole system each time you nudge a pixel.

## How the pieces connect

The QML lives in `modules/home/quickshell/qml/`. Nothing on the machine reads that folder directly. On every rebuild, `modules/home/quickshell/default.nix` copies it into the Nix store and adds two generated files:

- `theme.json`, made from `modules/nixos/theme.nix`. Colours, corner radii, opacity, spacing and fonts all come from here.
- `icons.json`, which maps Lucide icon names such as `wifi` to characters in the Lucide icon font.

Home Manager then links that store copy to `~/.config/quickshell`, and niri starts `qs` at login, which loads `~/.config/quickshell/shell.qml`.

The practical upshot is that editing the repo changes nothing until you rebuild, unless you run the shell straight from the repo. Both ways are covered below.

## Where things are

Inside `modules/home/quickshell/qml/`:

| Path | What's in it |
| --- | --- |
| `shell.qml` | The entry point. It creates a bar, dock and wallpaper for each monitor, one of each popup, and the `qs ipc` commands that niri's key bindings call. |
| `modules/` | Whole surfaces. `Bar.qml`, `Dock.qml`, `ControlCenter.qml`, `StatusMenu.qml`, `ClipboardHistory.qml`, `Launcher.qml`, `Lock.qml`, `Osd.qml`, `Settings.qml` and so on. |
| `modules/cc/` | The pages. `NetworkPage.qml` is Wi-Fi, then `BluetoothPage.qml`, `SoundPage.qml` and `MediaPage.qml`. Each is one self-contained component that works in more than one place. |
| `components/` | Pieces used in many places. Change one of these and every panel that uses it changes too. |
| `services/` | Singletons that hold state and talk to the system. QML files use them by name, like `Net.wifiOn` or `Audio.volume`. |

Each page lives in two places. Inside the control centre, the arrow on the Wi-Fi tile slides `NetworkPage` in over the grid. On the bar, the Wi-Fi icon opens a separate popup, a `StatusMenu`, that holds its own copy of `NetworkPage`. Bluetooth and Sound work the same way. `shell.qml` creates the three menus:

```qml
StatusMenu { id: networkMenu; name: "network"; page: Component { NetworkPage {} } }
```

So to change what the Wi-Fi menu shows, edit `NetworkPage.qml`, and both places pick it up. To give another bar icon its own menu, write a page whose root is a `SubPanel`, add a `StatusMenu` line like the one above, and set `menu: "yourname"` on its button in `Bar.qml`.

The components you'll touch most:

- `SubPanel.qml` is the frame of every control-centre page. It has the title and switch row, a divider, the scrolling list, and the "… Settings" link at the bottom.
- `ListRow.qml` is one row in those lists. It has a round icon, a title, an optional status line, and a slot on the right for extras like a lock icon or battery level.
- `Glass.qml` is the frosted black surface behind every menu.
- `PillToggle.qml` and `CircleToggle.qml` are the wide and round buttons in the control centre grid.
- `Label.qml` is text in the theme font. `HeaderLabel.qml` is a bold title that lines its capital letters up with whatever sits next to it.

The services worth knowing:

- `Theme.qml` reads `theme.json`. Use `Theme.colors.text`, `Theme.spacing.panel` and friends instead of typing colours and sizes by hand.
- `ShellState.qml` tracks which popup is open by name, such as `"control"` or `"network"`. Only one is open at a time, and `ShellState.toggle(name)` opens or closes one.
- `Net`, `Bt`, `Audio`, `Brightness`, `Media`, `Notifs` and `Clipboard` wrap NetworkManager, BlueZ, PipeWire and the rest.
- `Prefs.qml` stores choices made in Settings, such as panel opacity and Focus mode.

## How the layout works

The panels are built from Qt Quick Layouts. If you've used flexbox or a grid component in a React UI kit, this will feel familiar.

`RowLayout` and `ColumnLayout` line their children up in a row or a column. Children don't say where they go. They say how they want to be sized and aligned:

```qml
RowLayout {
    HeaderLabel {
        text: "Wi-Fi"
        Layout.fillWidth: true            // take the spare width
        Layout.alignment: Qt.AlignVCenter // centre it vertically in the row
    }
    Switch {
        Layout.alignment: Qt.AlignVCenter
    }
}
```

`GridLayout` runs the control centre. It has four equal columns. Each tile says how many columns it covers with `Layout.columnSpan`, and Now Playing also sets `Layout.rowSpan: 2`. Widths come from `root.span(n)`, the width of `n` columns plus the gaps between them. I tried letting the grid share out widths by itself first, and it squeezed the two-column pills down to one column. Explicit spans are what keep the columns even.

Spacing comes from three values in `theme.nix`:

| Value | Size | Used for |
| --- | --- | --- |
| `Theme.spacing.panel` | 14 | Padding between the glass edge and everything inside it. |
| `Theme.spacing.tile` | 10 | The gap between controls. |
| `Theme.spacing.inset` | 10 | How far text sits inside a row, header or footer. |
| `Theme.bottomPadding` | 24 | `panel` plus `inset`. Extra room under panels that end in a box or small text. |

Panels pad their sides and top by 14 px, and boxes (tiles, rows, the search field, hover highlights) run out to that edge. Text that isn't inside a box lines up with the boxes' edges, except in the Wi-Fi, Bluetooth and Sound pages, whose text sits 10 px further in, level with the text inside their rows. The bottom gets more room: a page ends in a 32 px "… Settings" row, so its text sits about 24 px above the border, and the control centre grid and the clipboard menu use `Theme.bottomPadding` to match. Round icons in rows sit 4 px further out than text, the way macOS does it.

A few rules that will save you some confusion:

- Don't use `anchors` on an item that sits directly inside a layout. The layout positions it, the anchors try to as well, and you get warnings and odd jumps. Anchors are fine one level down, inside a plain `Item`, `Rectangle` or `Row`.
- A layout reads a child's `implicitWidth` and `implicitHeight`. A component that only sets `height: 70` can collapse to nothing inside a layout. Set `implicitHeight` instead, or give the child `Layout.preferredHeight`.
- If a number keeps showing up in several files, it probably belongs in `theme.nix`.

## Trying changes live

You can run the shell straight from the repo, and Quickshell reloads every time you save a file. Use this for almost all UI work.

Open a terminal on the desktop (Super+T):

```bash
cd ~/documents/github/system-configs/nixos/modules/home/quickshell/qml

# Once. Copy the two generated files next to the QML, with start-up locking
# turned off so the dev copy doesn't lock your screen when it starts.
cp ~/.config/quickshell/icons.json .
sed 's/"lockOnStart":true/"lockOnStart":false/' ~/.config/quickshell/theme.json > theme.json

# Stop the installed shell and run this folder instead.
qs kill
qs -p .
```

Errors and anything you print with `console.log("…")` show up in that terminal. Leave it running and edit files in Zed. Each save reloads the shell.

To open the thing you're working on without clicking around, use a second terminal. The `-p .` sends the command to the dev copy:

```bash
qs ipc -p . call control toggle
qs ipc -p . call control openPage network   # a page inside the control centre: also bluetooth, sound and media
qs ipc -p . call menu toggle network        # the bar's own menu: also bluetooth and sound
qs ipc -p . call clipboard toggle
qs ipc -p . call launcher toggle
```

When you're done, press Ctrl+C in the first terminal and run `qs -d` to bring the installed shell back. `qs list` shows which shells are running.

Two things don't update live. Changes to `theme.nix` only reach `theme.json` on a rebuild, though you can edit the copied `theme.json` to experiment. Changes to Nix files, such as niri key bindings, need a rebuild too. Git ignores both copied JSON files, so they won't end up in a commit.

## Making changes permanent

```bash
cd ~/documents/github/system-configs
git add -A                                     # the build only sees files git knows about
sudo nixos-rebuild switch --flake .#framework
qs kill; qs -d                                 # restart the shell, or log out and back in
git commit -m "feat(nixos): …"
git push
```

Push your changes. The laptop upgrades itself every day from the GitHub copy of this repo, so anything you only switched to locally disappears at the next reboot.

## Checks

These run headless and finish in a minute or two:

```bash
nix build --no-link .#checks.x86_64-linux.shellPopups        # popups open, change pages and close cleanly
nix build --no-link .#checks.x86_64-linux.dropdowns          # Settings dropdowns
nix build --no-link .#checks.x86_64-linux.clipboardSelection # keyboard selection in the clipboard menu
nix build --no-link .#checks.x86_64-linux.brightness         # parsing ddcutil output
```

`nix flake check` runs all of them and builds both machines. On GitHub, the NixOS check workflow runs every one except `brightness` whenever a push touches `nixos/`.

## Trying it in the VM

`./nixos/run-vm` builds the current config and boots it in QEMU, viewed over VNC on `127.0.0.1:5902`. It's the safest place to try anything that touches the lock screen or session, because a broken lock screen there costs you a VM restart and nothing else.
