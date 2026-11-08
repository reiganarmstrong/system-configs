# Fedora with Niri and Noctalia

`niri.yml` turns a Fedora 45+ install into a [Niri](https://github.com/niri-wm/niri) scrolling-tiling session with the [Noctalia](https://github.com/noctalia-dev/noctalia) v5 shell, in a monochrome look called Graphite. It's a separate profile from `desktop.yml` (GNOME with PaperWM). It reuses that profile's app and shell tasks, and GNOME stays installed and selectable at the login screen.

Niri 26.04 or newer is required for background blur and for optional config includes, and Noctalia must be the native v5 shell. Fedora 45 ships both (`niri-26.04`, `noctalia-5.4.1`), so the role refuses older releases.

The profile enables small floating-panel fade and quiet Control Center patches by default. Its first provisioning run installs build dependencies and compiles a custom Noctalia RPM from Fedora's signed source. Unchanged runs reuse it. Set `-e niri_noctalia_panel_fade_enabled=false` to use the stock package instead; [NOCTALIA-FADE.md](NOCTALIA-FADE.md) explains updates and rollback.

## Install

Start from Fedora 45 Workstation (or Everything with GDM), with a normal administrator account that has a password, and log in as that account.

```bash
sudo dnf install -y git python3-pip
git clone https://github.com/reiganarmstrong/system-configs.git
cd system-configs/fedora
./bootstrap.sh
.local/ansible/bin/ansible-playbook niri.yml --ask-become-pass
```

Reboot, enter your password at GDM, and you land in Niri. Use `-e niri_user=NAME` to configure another existing account. The [Framework hardware guide](FRAMEWORK.md) covers stock firmware, fingerprint enrollment, Tailscale sign-in and physical device checks. To preview changes on an already configured machine, add `--check --diff`.

Tailscale is installed and started, with your account set as its operator, as on NixOS. Run `sudo tailscale up` once after installation and complete the browser sign-in, then `sudo tailscale set --operator="$USER"` to persist your account's permission on that login profile. Ansible never authenticates or resets an existing connection. Set `-e niri_tailscale_enabled=false` to skip its setup.

### Reproducing this profile on the Framework 13 Pro

Use the checkout containing this profile. The current development branch is `t3/fedora-niri-noctalia-profile`; a clone of the default branch only includes it after those commits have been published there. Nothing in the VM's ignored `.local/niri-vm/` directory is needed to configure the laptop.

If transferring an unpublished branch, create a Git bundle from this checkout:

```bash
git bundle create /tmp/fedora-niri-profile.bundle t3/fedora-niri-noctalia-profile
```

Copy the bundle to the laptop, then use it instead of the GitHub clone in the install instructions:

```bash
git clone --branch t3/fedora-niri-noctalia-profile /path/to/fedora-niri-profile.bundle system-configs
cd system-configs/fedora
./bootstrap.sh
.local/ansible/bin/ansible-playbook niri.yml --ask-become-pass
```

The playbook needs internet access for Fedora packages, Flatpak apps, developer tools and checksum-pinned icon downloads. It reproduces the configuration and app selection; Fedora and Flatpak package versions can advance with their repositories.

| Part of the desktop | Tracked source |
| --- | --- |
| Niri layout, widths, shortcuts and blur | `roles/niri/templates/config.kdl.j2` |
| Top bar, glass menus, dock and idle behavior | `roles/niri/templates/noctalia.toml.j2` |
| Panel fade, quieter Control Center selection and Fedora RPM rebuild | `roles/niri/tasks/noctalia-fade.yml`, [NOCTALIA-FADE.md](NOCTALIA-FADE.md) |
| Centered app search | `roles/niri/templates/fuzzel.ini.j2` |
| Shell colors and terminal appearance | `roles/niri/files/Graphite.json`, `ghostty.config`, `starship.toml` |
| Approved Fedora/specification wallpaper | `roles/niri/files/wallpaper-fedora.png` and its generation record |
| Light app icons and fallback theme | `roles/niri/tasks/icons.yml`, `roles/niri/vars/macos-icons.yml` |
| Apps, login, keyring, services and GTK/Qt settings | `roles/niri/tasks/` and the shared `roles/desktop/` app/shell tasks |

Keep the laptop defaults for the first run: `niri_outputs: []` lets Niri choose the built-in panel's preferred mode and scale, GDM requires a password, and idle locking and suspend are enabled. The VM's MacBook-sized output and disabled idle actions are test overrides, not laptop defaults. Tailscale setup is now also tested in the guest, which stays unenrolled. The wallpaper's CPU, memory and disk lines describe the supplied laptop specification, not values discovered from the guest.

After rebooting and logging in with your password:

- Check `niri validate` and `noctalia config validate`, then rerun the playbook with `--check --diff` to look for drift.
- Test Wi-Fi, Bluetooth, battery and brightness on the real devices, plus lid suspend and resume. The VM cannot verify these.
- Test audio, screen sharing and external monitors. Complete the Tailscale sign-in and operator steps in [FRAMEWORK.md](FRAMEWORK.md), and add online accounts as needed.
- If personal settings hide a managed change, inspect Noctalia's overrides described in [Personalizing](#personalizing), rather than deleting the entire settings file.

### Choosing and reverting the session

GDM's gear menu (bottom right, after picking the user) lists **Niri** and **GNOME**. The playbook preselects Niri through AccountsService (`niri_default_session: true`) and resets it to Niri on every run. Set `-e niri_default_session=false` to keep whatever you last chose at GDM.

To go back to GNOME for good, pick GNOME at GDM and run `desktop.yml` again. It reapplies the GNOME look to the settings the two profiles share (see [Shared state](#shared-state-between-profiles)). To remove the Niri profile completely:

```bash
sudo dnf remove niri noctalia xwayland-satellite
rm -r ~/.config/niri ~/.config/noctalia ~/.local/state/noctalia \
      ~/.config/xdg-desktop-portal/niri-portals.conf
```

`niri.yml` configures an existing Fedora machine. To create an independent test VM with the existing VM role, run `vm.yml --tags provision` with a separate `vm_name`, `vm_mac`, `vm_vnc_port` and `vm_local_directory`. That skips the GNOME configuration and its automatic-login policy. Set the guest account's password over its administration SSH connection, then run `niri.yml` against the generated inventory. See the live VM verification below.

## Shortcuts

Super is `Mod`. Super+Shift+/ shows every binding with its title.

| Keys | Action |
| --- | --- |
| Super+T | Ghostty |
| Super+E | Files (Nautilus) |
| Super+Space | Fuzzel app search, press again to close |
| Super+, | Noctalia settings |
| Super+S | Control center (audio, network, Bluetooth, brightness, power profile) |
| Super+Shift+V | Clipboard history |
| Super+N | Do not disturb |
| Super+L | Lock |
| Super+Shift+E | Session menu (log out, suspend, reboot, shut down) |
| Alt+Tab | Window switcher |
| Super+Q | Close the window |
| Super+F / Super+Shift+F / Super+Ctrl+F | Fullscreen / maximize column / fill the remaining width |
| Super+V | Float or tile the window |
| Super+Shift+Tab | Switch focus between floating and tiled windows |
| Super+R, Super+− / = | Cycle column width presets (½, ⅔, 100%), narrow or widen by 10% |
| Super+C, Super+W | Center the column, tab the column |
| Super+[ / ] | Pull the neighbouring window into this column, or push it out |
| Super+arrows, Super+Shift+arrows | Focus, move |
| Super+Ctrl+arrows (add Shift to take the column) | Focus another monitor |
| Super+1…0, Super+Shift+1…0 | Go to workspace, move the column there |
| Super+O | Overview |
| Print, Ctrl+Print, Alt+Print | Screenshot a region, screen, window (saved to `~/Pictures/Screenshots`, copied to the clipboard) |
| Super+Shift+S | Region screenshot with annotation (Noctalia) |
| Volume, mute, mic, brightness, media keys | Noctalia, with its on-screen display; they also work on the lock screen |
| Super+Escape | Let an app (VM viewer, remote desktop) keep the shortcuts it grabbed, or take them back |
| Super+Shift+P | Turn the displays off |
| Ctrl+Alt+Delete | Quit Niri (asks first) |

Super+drag moves a window, and Super+right-drag resizes it (Niri defaults). Shell shortcuts go through `noctalia msg`, Noctalia's IPC, except app search, which toggles the user's named Fuzzel instance. `tests/check_niri_keybinds.py` checks every one against the installed Noctalia (see [Testing](#testing)).

The layout's initial column width is `proportion 1.0` (100% of the usable width). Super+R cycles `0.5`, `0.66667` and `1.0`, in that order. These settings control initial sizing and manual cycling; opening another app does not resize existing columns. Existing window-specific rules still take precedence, including Calendar's two-thirds initial width and the floating Noctalia settings window's fixed size.

Click the time in the center of the top bar to open the control center. App search uses Fuzzel, centered on the screen, with a dark glass body, a subtle darker-gray selection, light text and an unboxed search prompt. It uses the same app icons as the dock. There are no category chips, subtitles, search-field border or focus ring. Super+Space toggles only the named app-search instance, leaving other Fuzzel pickers alone. Terminal apps such as btop use the configured Ghostty terminal through `xdg-terminal-exec`.

The user chose Fuzzel to make launcher styling independent of Noctalia's shared colors. App search no longer includes Noctalia's calculator, emoji, `/` providers, pinned-first sorting or icon grid. Noctalia still supplies clipboard history, settings, lock screen, media controls and the other shell shortcuts. Its launcher configuration remains available for explicit IPC use. The dock's built-in launcher button is hidden because it always opens Noctalia search; use Super+Space for app search.

Fedora's package also ships a "Noctalia" launcher entry that only starts the already-running shell daemon. A user-level override hides that entry; Super+, opens Noctalia's settings. Control center, wallpaper and session menus float near the bar with glass styling. Clipboard history and polkit prompts stay centered and floating. Niri covers the bar during fullscreen; menus retain their own Overlay layer and remain accessible.


## Graphite

The NixOS desktop uses a hand-built Quickshell bar. Graphite uses black, white and gray shell controls, with chrome as frosted glass over the wallpaper. The Fedora fetch wallpaper adds one blue palette swatch. Shell status colors still carry meaning: red for errors and urgent windows, amber for warnings, green for success in the terminal.

The dock, notifications, OSD, floating Noctalia panels and window switcher are translucent with real background blur. The top bar remains solid black; its menus float independently with glass styling (see [Top bar](#top-bar)). Fuzzel uses its own 84%-opaque Graphite surface with real Niri blur, rounded to match its 16 px border. App windows stay opaque, so text sits on a solid surface. Ghostty's 84%-opaque background blurs the wallpaper behind it using Niri's default xray blur.

| Token | Value | Used for |
| --- | --- | --- |
| Surface | `#0a0a0b` | Shell and terminal background, wallpaper fill |
| Surface variant | `#18181a` | Cards, input fields |
| Hover | `#26262a` | Hover and pressed states |
| Outline | `#3a3a3f` | Separators, selections |
| Text | `#ececee` | Primary text |
| Muted text | `#a3a3a9` | Secondary labels |
| Primary | `#a3a3a9` | Noctalia selections and active controls, with dark text |
| Secondary | `#7c7c83` | Focus rings and secondary labels |
| Error | `#ff5c5c` | Errors, urgent window border |
| Warning | `#d4a95a` | Warnings (terminal yellow, Starship's warning style) |
| Active border | `#ffffff5c` | 1 px focused-window hairline |
| Inactive border | `#ffffff1a` | 1 px hairline on other windows |

Primary and Secondary are shared Noctalia roles used by Settings selections, control-center active tiles, clipboard selections, slider fills and input focus rings. Fuzzel has its own colors and does not change these roles. The active workspace pill uses a fixed `#f2f2f3` fill with calculated dark text, keeping it distinct from these selections. Terminal colors and the light palette are unchanged.

These values live in `roles/niri/files/Graphite.json` (Noctalia's palette, including the 16 terminal colors), `ghostty.config`, `starship.toml`, `btop-graphite.theme` and `templates/config.kdl.j2`. App-search colors live only in `templates/fuzzel.ini.j2`: body `#18181a` at 84% opacity, selected row `#2e2e31` at 90%, normal text `#e4e4e6` and selected text `#ffffff`. A scoped Niri layer rule blurs the windows behind it and matches its rounded corners. The layout keeps the flat reference's quiet selection and plain prompt; the later glass revision restores the desktop's translucent material.

- **Geometry.** 12 px gaps and 14 px corners on windows, 18 px on the dock. The top bar is a flat 34 px strip. A soft drop shadow and a hairline border mark the focused window. Niri's border does not draw behind Ghostty's translucent background.
- **Blur.** Niri 26.04's `blur` block uses 3 passes, a small offset, a little noise against banding and 60% saturation, so colorful windows behind the glass don't tint it. Noctalia's layers and floating windows use non-xray blur, so they blur the windows that are really behind them. Niri marks non-xray blur experimental.
- **Type.** Inter for the UI and JetBrains Mono for terminals and code, from Fedora's packages.
- **Wallpaper.** `roles/niri/files/wallpaper-fedora.png` is a Python-rendered Fedora ASCII logo and fetch-style specification panel on graphite, using real monospace glyphs. It lists the user's Framework 13 Pro, Intel Core i5, 32 GB RAM and 1 TB SSD, plus niri and Noctalia. The bundled image is native 2880×1920 for the target laptop; Noctalia scales and crops it for other outputs. Its installed filename includes its SHA-256 fingerprint so replacing the asset bypasses Noctalia's image cache. The image is copied before its config is published, with no rendering tool needed at install time. The [generation record](roles/niri/files/wallpaper-fedora.md) identifies the source project, exact commit, preset, reproduction command and logo license. The former SVG-only `niri_wallpaper_size` variable remains retired; Noctalia handles output sizing directly.
- **Lock screen.** A blurred, darkened copy of the wallpaper with the clock, drawn by Noctalia.
- **GTK and Qt.** libadwaita apps get dark mode and the Slate accent (libadwaita's gray) from dconf. GTK 3 apps get `adw-gtk3-dark`, a port of the libadwaita look. Qt apps follow GTK through `QT_QPA_PLATFORMTHEME=gtk3`. There's no custom app CSS. Overriding libadwaita's stylesheet tends to break with each GNOME release. Windows use server-side decorations where apps support them.
- **Terminal.** Ghostty and Starship use brighter functional colors within the dark glass terminal: green for valid commands and user/host, blue for directories, magenta for git branches, cyan for runtimes, yellow for strings and dirty trees, and red for errors. ANSI 8 is a readable gray for the autosuggestion plugin's default `fg=8`. The 16 Ghostty slots match `Graphite.json`'s dark terminal palette; Noctalia's UI roles and the light palette remain separate. Starship keeps its layout and ASCII-only symbols. btop gets a matching transparent theme, and fastfetch is an optional first-level greeting. Reload Ghostty with Ctrl+Shift+, to refresh existing terminals; new prompts pick up Starship's colors naturally.
- **Icons.** `Graphite-macOS-Light` uses light-mode app icons selected from [macOSicons.com](https://macosicons.com/). Every currently installed launcher app has a mapping, with suitable stand-ins for apps missing from the site. Zen uses the exact requested `0AeL19Hq0J` icon, and T3 Code uses the official Nightly macOS PNG from a pinned upstream commit. Selecting its artwork does not change the app's release channel. The original 1024 px PNGs are extracted unchanged from checksum-pinned Mac icon files. The user theme inherits Papirus-Dark for folders, status symbols and future unmapped apps. Fedora's separate `papirus-icon-theme-dark` package remains installed, and normal provisioning fails if either required theme is missing. The shell and GTK theme stay dark. See [MACOS-ICONS.md](MACOS-ICONS.md) for sources, substitutes and maintenance.

### Top bar

A solid black strip, 34 px tall, runs across the top of every output. It has no transparency, blur, border, shadow or rounded corners. Control center, wallpaper and session menus use native floating placement with translucent bodies, rounded corners, a fine border and blur. They stay near the bar without sharing its fill or layer. Niri's 12 px gap separates the bar from tiled windows.

The bar uses the Top layer, so Niri draws fullscreen content over it automatically. Floating menus explicitly use Overlay and stay accessible over fullscreen without revealing the bar. Leaving fullscreen exposes the bar again. App search, clipboard and polkit stay centered and floating. No hide shortcut or fullscreen watcher is required.

Floating Noctalia panels use a local 150 ms fade patch, leaving their geometry stationary while the whole card changes opacity. The role rebuilds Fedora's signed source RPM and caches the result. Rerun provisioning after a Noctalia package upgrade to reapply it to the new version; an incompatible patch stops the build. Set `niri_noctalia_panel_fade_enabled=false` to restore the stock package and wipe animation. See [build, upgrade and rollback details](NOCTALIA-FADE.md).

Active Control Center shortcut tiles and the active sidebar item stay white with dark icons in the dark theme, including while hovered. Press dims the white surface slightly, keeping the same icon contrast instead of alternating between white and dark tiles. Inactive tiles have a small tonal press response before the actual on/off change. This is a separate scoped patch in the same package; global palette accents and keyboard focus stay unchanged. Restoring the stock package restores its original button styling too.


- **Left:** numbered workspace pills. The active one is white with dark text and only half again as long as the round inactive ones. Workspaces with windows use a lighter gray fill than empty ones.
- **Center:** the time, alone in Noctalia's center lane, so it stays centered on the output whatever the side lanes hold. Clicking it opens the control center on Home, with its tab sidebar.
- **Right:** media, tray, notifications, network, Bluetooth, volume, brightness, battery and the power button. Each opens its own panel beneath it instead of the full control center: network opens the Network tab, volume the Audio tab, Bluetooth its tab, brightness the Monitor tab, battery the Power tab and notifications the history. Opened this way, the control center shows that one tab with no sidebar (`[control_center] sidebar_section = "none"`). The power button opens the session menu. Right-click keeps Noctalia's shortcuts: network and Bluetooth toggle their radio, and notifications toggles Do Not Disturb.

Noctalia's shell close buttons are hidden with `shell.show_close_buttons = false`. Dismiss widget menus with Escape or an outside click. This native switch also hides notification, dialog and Settings close controls: notification toasts still dismiss with right-click, dialogs retain Cancel, and Settings closes with Super+Q.

Widgets with no device hide themselves: brightness without a backlight and battery without a battery. Bluetooth hides on machines without an adapter but otherwise stays visible, so pairing is one click away. Network names stay in the tooltip, so a long SSID can't stretch the bar.

Status glyphs use native per-widget `scale = 1.25` (20 px instead of 16 px) and an 8 px gap. Noctalia's bundled icon font has no configurable stroke weight; the larger size gives its lines more weight. Clock text, workspace pills and bar height stay unchanged. The graphic battery stays at its original size because its outline is already heavier.

These single-tab cards are the control center's own tabs, not separate popovers. Noctalia 5.4.1 has no standalone network, audio or Bluetooth panels, and building them would mean a plugin that has to track Noctalia's internals on every upgrade. Its tab cards keep the control center's fixed height, so a short tab such as Network on a wired VM leaves empty space below its content.

An earlier attached candidate with a Top-layer bar opened invisible menus underneath fullscreen apps. Moving both to Overlay fixed access but left the bar over video and made the menus opaque. The current floating placement separates menu stacking from the bar, restoring fullscreen and glass through native settings. The tray drawer remains a separate native popover. The [fullscreen verification record](reviews/niri-glass-fullscreen.md) covers live stacking, dismissal and blur checks.

This bar replaces the earlier floating notch (a capsule group inside a transparent bar), whose [review record](reviews/niri-notch.md) is kept for history.

## Services

Noctalia is a full shell, so most session services come from it. Niri's competing weak dependencies (waybar, swaylock, mako-style tools, gnome-keyring) are skipped (`install_weak_deps: false`) so nothing runs twice.

| Need | Provided by |
| --- | --- |
| Login | GDM with a password and the `niri` Wayland session. Automatic login is off. |
| Bar, dock, tray, OSD, notifications | Noctalia, started by Niri (`spawn-at-startup`). It's the only notification daemon. |
| App search | Fuzzel, with its own validated dark glass theme and the shared app icon theme. |
| Lock screen | Noctalia, checked against the `login` PAM stack for passwords, with native fprintd support for enrolled readers. It locks before suspend. |
| Idle | Noctalia: lock at 5 min, displays off at 6 min, suspend at 15 min (`niri_idle_*_seconds`, 0 disables). Apps that inhibit idle, such as video players, are respected. |
| Polkit prompts | Noctalia's built-in agent (`polkit_agent = true`). |
| Keyring | Fedora 45's `oo7-daemon`, started as a dependency of `niri.service` and stopped with the graphical session. GDM's vendor `pam_oo7` stack hands it the login password. Fedora ships the daemon disabled, so installing its package alone is insufficient. A user-level `niri-portals.conf` routes the Secret portal to `oo7-portal` in Niri sessions only. Zed and Bitwarden use libsecret. |
| Portals | `xdg-desktop-portal-gnome` for screencasting and file choosers, `-gtk` for the rest (Niri's own `niri-portals.conf`). |
| X11 apps | `xwayland-satellite`, started by Niri on demand. |
| Audio, network, Bluetooth | PipeWire with WirePlumber, NetworkManager, BlueZ. Noctalia's control center fronts all three, so there's no separate applet. |
| Brightness, battery, power profiles | Noctalia over logind, UPower and whichever of `tuned-ppd` (Workstation's default) or `power-profiles-daemon` is installed. The package list asks for the shared `ppd-service`, so the two never fight. |
| Printing and printer discovery | CUPS with its socket enabled, Avahi, and `system-config-printer`. |
| VPN | Tailscale's signed stable RPM, with `tailscaled` enabled and the desktop account set as operator. Enrollment is interactive. |
| Lid and power button | systemd-logind defaults: suspend on lid close, and Noctalia locks first. |
| Clipboard | Noctalia's history, over `wl-clipboard`. |
| Screenshots | Niri's built-in tool, plus Noctalia's annotated region capture. Both save to `~/Pictures/Screenshots`. The keyring prompt, notifications and OSD are hidden from screencasts. |

## Apps and tools

The same set as the GNOME profile, from the same sources, via its `apps.yml` and `shell.yml`. That covers Zen (Flathub), Ghostty (COPR), T3 Code (checksummed AppImage), Claude Code (Anthropic's signed repo), Node 24 with npm and pnpm, uv, git, vim, make, curl, zsh with oh-my-zsh and Starship. On top of that, this profile adds:

- **Zed** replaces VSCodium. The official stable Linux bundle is SHA-256-pinned for the first install in `~/.local/zed.app`, with `~/.local/bin/zed` on PATH and its own desktop entry. Later runs preserve the app's native updates; `rsync` is installed for that updater, along with Mesa's Vulkan driver for the laptop GPU. Provisioning removes the old `codium` RPM and repository but preserves VSCodium settings, extensions and projects.
- **Bitwarden Desktop** comes from Flathub (`com.bitwarden.desktop`), so `flatpak update` keeps it current alongside Zen. Its sandbox can access the session's Secret Service. The role installs Bitwarden's native `com.bitwarden.Bitwarden.unlock` Polkit policy, which requires authentication as the active user. Sign in yourself and enable biometric unlock in Bitwarden after enrolling your fingerprint. No account data or vault credentials are stored in the repo.
- **Nautilus** and **GNOME Calendar** with GNOME Online Accounts and `evolution-ews-core`, so Exchange/Microsoft 365 calendars work. Add accounts in the standalone Online Accounts app (`gnome-online-accounts-gtk`), which replaces the GNOME Settings panel outside GNOME.
- **btop** and **fastfetch**.
- **Disks**, **Passwords and Keys** (`seahorse`), **Print Settings** (`system-config-printer`) and **PulseAudio Volume Control** (`pavucontrol`) retain the NixOS management tools. Noctalia replaces Blueman's connection/pairing controls, so its competing applet is not installed. Niri output settings replace `wdisplays`, which uses a different compositor protocol. Changes to connected displays go in `niri_outputs` or `~/.config/niri/local.kdl`.

The [Zed and Bitwarden verification record](reviews/niri-zed-bitwarden.md) covers migration, native app launches, exact icon checksums and test limits.

## Personalizing

Ansible rewrites the files it owns on every run, so edits to them don't survive. Each one has an override that Ansible never touches:

| Owned by Ansible | Put your changes in |
| --- | --- |
| `~/.config/niri/config.kdl` | `~/.config/niri/local.kdl`, included last, so it can add binds, outputs and window rules or override earlier settings |
| `~/.config/noctalia/00-fedora-niri.toml` | Noctalia's Settings window (Super+,), which saves to `~/.local/state/noctalia/settings.toml`. Or a later-sorting file such as `~/.config/noctalia/50-mine.toml`. Both take precedence. |
| `~/.config/fuzzel/fuzzel.ini` | No override; change `roles/niri/templates/fuzzel.ini.j2` |
| `~/.config/ghostty/config` | `~/.config/ghostty/local` |
| `~/.zshrc` | `~/.zshrc.local` |
| `~/.config/starship.toml`, btop's theme lines, fastfetch's config | No override; change them in the role |

Niri and Noctalia reload their config while running, so a rerun takes effect without logging out. Fuzzel reads its config each time it opens. All three configs are checked before they are written with `niri validate`, `noctalia config validate` and `fuzzel --check-config`.

Reordering bar widgets in Noctalia's Settings window saves lane and capsule-group overrides in `~/.local/state/noctalia/settings.toml`. Those override the role, and arrays replace rather than merge. If a later bar change does not appear, inspect the saved `[bar.main]` lanes and `capsule_group` entries, plus any widget overrides. Remove only the overrides you want the role to manage; other personal settings can stay.

Variables in `roles/niri/defaults/main.yml`:

- `niri_outputs` pins a display's mode, scale and position. By default nothing is pinned, and Niri picks each display's preferred mode and a fractional scale from its DPI. That gives the Framework 13's 2880×1920 panel a sensible scale with no host-specific connector name in the repo. To pin it, run `niri msg outputs` in the session and copy the name, then set for example `niri_outputs: [{name: eDP-1, scale: 1.75}]`. A monitor can be named by make, model and serial so it follows the cable. For a virtual output that needs a non-advertised size, `mode_custom: true` emits Niri's native custom-mode syntax; supply a refresh rate as in the VM-only profile below.
- `niri_keyboard_layout` and `niri_keyboard_options` set the XKB layout, such as `us` with `ctrl:nocaps`.
- `niri_idle_lock_seconds`, `niri_idle_screen_off_seconds` and `niri_idle_suspend_seconds`.
- `niri_dock_pinned` lists the dock's apps by desktop entry id.
- `niri_default_session` (see above).
- `niri_fingerprint_pam_enabled` adds fingerprint authentication to the existing authselect profile by default. Set false to leave PAM policy unchanged. See [FRAMEWORK.md](FRAMEWORK.md) for enrollment, password/keyring behavior and the stock hardware package list.
- `niri_tailscale_enabled` installs and starts Tailscale by default. Turning it off skips management; it does not uninstall or disconnect an existing installation.

## Shared state between profiles

`desktop.yml` and `niri.yml` configure the same account, and some settings exist only once. Whichever playbook ran last decides them:

- dconf's `org.gnome.desktop.interface` keys: color scheme, accent, GTK theme, icon theme and fonts. After `niri.yml`, GNOME uses the Slate accent and Graphite-macOS-Light icons until `desktop.yml` runs again.
- `~/.local/share/applications/t3code.desktop`: Niri selects its light coding-tool icon, while the GNOME profile keeps the app's original icon. Its name, command and URI handler are unchanged.
- `~/.zshrc` (the Niri profile adds the fastfetch greeting), `~/.config/starship.toml` and `~/.config/ghostty/config`.

Everything else is separate. Niri and Noctalia files are read only by Niri. The portal override only applies when `XDG_CURRENT_DESKTOP=niri`. GNOME's extensions and dock settings only load in GNOME.

## Coming from the NixOS desktop

| NixOS (Hyprland + Quickshell) | Fedora Niri |
| --- | --- |
| Hyprland, dwindle-style tiling | Niri, scrolling columns. Windows open to the right instead of splitting the screen. |
| greetd + tuigreet, automatic login with an immediate lock | GDM with a password login. The password also unlocks the keyring, which automatic login can't do. |
| Quickshell bar, launcher, control center, settings, OSD | Noctalia, on the same keys (Super+Space, Super+S, Super+,) |
| Quickshell lock + hypridle | Noctalia lock screen and idle (same 15-minute suspend) |
| hyprpolkitagent | Noctalia's polkit agent |
| blueman applet | Noctalia's Bluetooth panel |
| Disks, Seahorse, printer settings, pavucontrol | Same applications, with CUPS and Avahi for printing |
| wdisplays | Niri's output configuration and `niri msg outputs` |
| cliphist | Noctalia clipboard history (Super+Shift+V, as before) |
| playerctl media keys | `noctalia msg media` (MPRIS, same behaviour) |
| Calendar widget backed by Evolution Data Server | GNOME Calendar reads your Online Accounts. Noctalia's own calendar connects to CalDAV, Google or ICS separately, set up in its Settings. It doesn't read GNOME Online Accounts. |
| Catppuccin-derived colors | Graphite (above) |
| Display option set to one output name | `niri_outputs`, empty by default |
| Tailscale | Installed from the vendor's signed stable repository, with the same desktop operator; run `tailscale up` to sign in once |
| Nix-pinned packages, rollbacks | Fedora packages that move with `dnf upgrade`. No rollback beyond Btrfs snapshots, if you set them up. |

Keys that moved: Super+Shift+E opens the session menu, and Alt+Tab is Noctalia's switcher. Super+Q, Super+F, Super+V, Super+L, Super+T, Super+1…0 and the hardware keys mean the same as on NixOS.

## Testing

Run on November 6, 2026:

- **Ansible syntax check** of `niri.yml`, `desktop.yml` and `vm.yml`. All three pass.
- **Initial implementation provisioning runs** in a disposable Fedora 45 container (`fedora:45`, a `tester` account, a system D-Bus with `polkitd` and `accounts-daemon` started by hand, no booted systemd):
  - First run: changed=42, failed=0.
  - Second run: changed=0.
  - `--check --diff` on the configured container: changed=0, failed=0.
  - Afterwards these were all present: `niri-26.04`, `noctalia-5.4.1`, `oo7-daemon` without `gnome-keyring`, `power-profiles-daemon` as `ppd-service`, `codium`, `claude-code`, `ghostty`, Node 24, Zen from Flathub and T3 Code. The dconf keys were written, and AccountsService stored `Session=niri` / `SessionType=wayland` for the account.
- **Config validation** with the packaged tools:
  - `niri validate` accepts the rendered `config.kdl` and rejects a broken one.
  - `noctalia config validate` reports the rendered TOML valid with zero warnings.
  - `ghostty +validate-config` accepts the Ghostty config.
  - `fastfetch` runs with its config.
- **IPC cross-check.** `python3 -I tests/check_niri_keybinds.py ~/.config/niri/config.kdl` parses all 93 bindings and fails on duplicates. It checks that every `noctalia msg` command, choice and flag exists in the installed Noctalia's own `--help` (118 commands), and that the NixOS-era shortcuts are still bound to the intended actions. Misspelled commands, panel ids and session actions are caught.
- **`python3 -m unittest discover -s tests`** covers the JSONC settings merger: comments kept, user values never overwritten, file mode kept, broken files left alone.
- The GNOME profile's rendered `~/.zshrc` is byte-for-byte unchanged by the shared-task edits.

The subsequent code review found and fixed incomplete utility/VPN migration, loss of comments inside empty VSCodium settings objects, ignored wallpaper size changes, and personal Niri includes being missed during Ansible's temporary-file validation. The Niri profile's boolean switches also accept the documented `-e name=false` form. The follow-up checks used a new disposable Fedora 45 container:

- All 8 JSONC tests pass, including preservation of comments in an otherwise empty object. All three playbook syntax checks pass with Ansible 2.22.
- Both templates validate against Niri 26.04 and Noctalia 5.4.1 with defaults and output/keyboard/idle overrides. Validation rejects a broken personal include even when the main config is a temporary file. All 93 shortcuts still pass the IPC check.
- The added utilities install from Fedora without installing `gnome-keyring`. The packaged CUPS socket and Avahi service are enabled.
- Actual session-file and Tailscale provisioning tasks pass, with systemd tasks excluded because PID 1 is not systemd. A changed Tailscale operator is corrected; this was tested against a real, unauthenticated userspace `tailscaled`. Changing the wallpaper render to 1920×1200 generates a PNG with those dimensions and updates Noctalia's path. A second run and `--check --diff` both report zero changes.

These checks verify provisioning and configuration, not running desktop services.

The container checks could not exercise a graphical session. The later VM checks below cover some of that gap. Noctalia's panel ids (`launcher`, `control-center`, `clipboard`, `session`) come from its docs, because `--help` doesn't list them.

### Live VM verification

On November 6, 2026, a separate `fedora-niri` KVM guest was provisioned on the Ubuntu host with four CPUs, 8 GiB RAM, a 60 GiB disk, VirtIO 3D and headless EGL. Its authenticated VNC console listens on `127.0.0.1:5903`; another QEMU guest already occupied port 5902 and was left running. Guest administration state and logs are in ignored `.local/niri-vm/`.

The full native playbook completed successfully. A clean guest reboot followed by a password login at GDM started Niri 26.04, Noctalia 5.4.1 and the keyring at 1920×1080 with scale 1. The Login collection reported `Locked=false`, confirming the PAM password handoff worked. System and user managers reported no failed units.

The real session exposed two additional setup issues, now fixed in the role:

- Noctalia's first-run wizard appeared over the preconfigured desktop. The role now sets `shell.setup_wizard_enabled=false`, the upstream option for declarative deployments.
- The installed oo7 daemon was disabled and had no D-Bus activation file. The role now attaches the vendor service to `niri.service`, orders it after the compositor, and stops it with the graphical session. This starts it before GDM's 120-second password handoff expires, without starting it for an SSH-only login or changing GNOME's startup policy.

Verified over the actual VNC connection: password authentication, desktop rendering, Ghostty on Super+T, the Noctalia launcher on Super+Space, automatic idle lock/display-off, and manual Super+L followed by password unlock. A final playbook rerun reported `changed=0`. For the remote test VM only, automatic lock, display-off and suspend are now disabled through the `niri_idle_*_seconds` variables; manual locking still works. Guest Tailscale setup is skipped because the host provides the remote connection. Native laptop defaults are unchanged.

Still untested: MacBook client keyboard capture, measured blur/GPU performance, suspend/resume, portal dialogs and screencasting, sound output, Wi-Fi, Bluetooth, brightness controls, the window switcher's hold behavior and physical Framework hardware. QEMU VNC has no configured audio forwarding or shared clipboard.

### Notch verification

The notch was tested in that running VM on November 6, 2026. Opus 5.5 at medium effort designed it and reviewed screenshots of the first implementation. That review rejected hover expansion because it moved the clock under the pointer. The final configuration follows the review's steady-row revision. Codex implemented the configuration, reviewed upstream layout and input handling, and tested the revision.

- Clicking the time immediately or after a 500 ms hover opens the control center in both cases. Clicking an empty workspace pill after a 500 ms hover selects that workspace when a second workspace exists.
- Control center, launcher, clipboard, session and wallpaper panels open below the notch. Screenshots at scales 1, 1.25 and 1.5 show the capsule and control center fitting on screen. The final layout also renders with native animations disabled, and the temporary override was removed afterward.
- The rendered configuration passes `noctalia config validate` with zero warnings. The final full playbook rerun reports `ok=65 changed=0 failed=0`; system and user managers report no failed units.

The VM has no battery, Wi-Fi adapter or Bluetooth device. Their appearance and tooltips still need a hardware check. Multi-monitor placement and the estimated fully populated laptop width have not been measured. The [notch review record](reviews/niri-notch.md) explains the design tradeoffs and resolved findings.

### Current MacBook TigerVNC display

The test VM is pinned to 1512×982 at 60 Hz and scale 1 using [profiles/niri-vnc-macbook.yml](profiles/niri-vnc-macbook.yml). Its previous unpinned preferred mode had become 1920×1080, larger than the earlier MacBook viewport. This profile selects an explicit native custom mode for `Virtual-1`, independent of later client resize requests. The normal Framework defaults stay automatic.

Apply the VM-only display profile after your inventory and other test variables:

```bash
.local/ansible/bin/ansible-playbook -i .local/niri-vm/vm.yml niri.yml \
  -e @.local/niri-vm/desktop-vars.yml -e @profiles/niri-vnc-macbook.yml
```

On the Mac, keep the existing SSH tunnel open:

```bash
ssh -N -o ExitOnForwardFailure=yes \
  -L 127.0.0.1:5903:127.0.0.1:5903 reagan@pc.taila028da.ts.net
```

Then run [viewers/macbook-tigervnc.command](viewers/macbook-tigervnc.command) on the Mac, or double-click it from a cloned checkout. It starts a fresh TigerVNC instance in fullscreen, disables RemoteResize and automatic encoding/color selection, requests the matching desktop size and uses full-color lossless Tight encoding. No password is stored in the helper. It needs the installed TigerVNC app and the existing tunnel; it does not create either one.

The [TigerVNC viewer options](https://tigervnc.org/doc/vncviewer.html) explain the resize, color and JPEG settings. `RemoteResize` and `DesktopSize` are passed as CLI flags because the stable saved-profile reader does not accept those fields. A smaller viewer window can still need panning. Matching the Mac's logical desktop avoids fractional shrinking; it does not change the official Mac app's Retina rendering capability. The helper was syntax-checked and its flags checked against upstream; the Mac client itself was not operated remotely.

### Earlier MacBook viewer and launcher follow-up

This earlier automatic-size approach is superseded by the pinned profile above.

The VM's test variables no longer pin `1920x1080`. Niri now uses the virtual display's preferred mode, which the MacBook's VNC viewer sets to its window size (1512×982 at scale 1 when checked), so the desktop fills the window instead of being scaled down into it. The production role is unchanged: `niri_outputs` is still empty by default.

Screenshots from the VM showed the numbered workspace pills in the then-current notch, a launcher without the category row, and no result for "noct" after the Noctalia entry was hidden. `noctalia config validate` reports the configuration valid.

### Solid top bar verification

Checked in the same VM at 1512×982 on November 6, 2026. `noctalia config validate` reports the configuration valid, and the playbook apply changed only Noctalia's config file.

- The clock is drawn at x=756 on the 1512 px output, its exact center.
- A full-height tile is 924 px: 982 − 34 (bar) − 924 = 24, so the gap is 12 px above and 12 px below.
- Clicking the network and volume icons opens the Network and Audio tabs alone, beneath the icon. Clicking the time opens Home with the sidebar, and the power button opens the session menu beneath it.

The VM has no Wi-Fi, Bluetooth adapter, battery or backlight, so those widgets and their cards still need a check on the laptop.

### Previous joined menus, glass search and Framework verification

Opus 5.5 at medium effort designed the earlier joined menus and dark glass Fuzzel launcher. Native attachment uses the Overlay bar layer, as chosen by the user, so menus and bar remain visible in fullscreen. The exact Zen and official T3 Nightly macOS icons are installed. The global width is 100%, with 50%, two-thirds and 100% presets; live reload and actual Super+R cycling were verified without resizing existing columns.

All three config validators pass, all 93 shortcut checks and 13 unit tests pass, and the final normal rerun reports `ok=102 changed=0 failed=0`. The final dry run reports `ok=93 changed=0 failed=0`. The [review record](reviews/niri-framework-ready.md) covers glass corner/blur checks, fullscreen interaction, icons, fingerprint policy guards and Tailscale dry runs. Physical device testing, fingerprint enrollment and Tailscale browser sign-in remain laptop steps in [FRAMEWORK.md](FRAMEWORK.md).

### Previous launcher grays and flush menus verification

On November 7, 2026, Opus 5.5 at medium effort approved actual VM captures of the softer launcher selection, quieter search ring and gapless glass menus. Codex verified keyboard search and app launching, bar clicks, menu placement at scales 1, 1.25 and 1.5, reduced motion and fullscreen access. Both native config validators pass. The final unchanged Ansible rerun reports `ok=78 changed=0 failed=0`.

The [review record](reviews/niri-launcher-and-menus.md) documents the shared palette effects and why native attached placement was rejected after it opened invisible menus beneath fullscreen windows. The final implementation uses only palette values and supported settings in the role.

### Fedora fetch wallpaper verification

After the user approved the Python-rendered preview, the exact 2880×1920 PNG was installed in the running VM and bundled in the role. Its installed SHA-256 matches the approved source, and an actual 1920×1080 desktop capture confirms the centered composition survives Noctalia's crop. The displayed specifications describe the user's target Framework laptop, not the VM's virtual hardware.

The full playbook apply reports `ok=65 changed=2 failed=0`; the final rerun reports `ok=65 changed=0 failed=0`. Native Noctalia validation has zero warnings. The [generation record](roles/niri/files/wallpaper-fedora.md) documents how to reproduce or update the image from the Python project.

### Previous Spider-Verse wallpaper verification

GPT's built-in image generation tool produced the bundled raster. Claude Opus 5.5 at medium effort approved the asset and actual 1920×1080 VM captures of the desktop, control center and Ghostty. The red, black, gray and white composition leaves the notch area quiet and text readable. The minimal dark center makes the glass subtler than the previous graphite folds. The source is 1586×992, so fine halftone dots and web lines soften when enlarged; it is not native 4K art. A 3:2 crop was judged from composition geometry, without a physical hardware test.

The full playbook apply reports `ok=65 changed=2 failed=0`. Its rerun reports `ok=65 changed=0 failed=0`, and `--check --diff` reports `ok=64 changed=0 failed=0`. The installed PNG's SHA-256 matches the bundled asset, native configuration validation has zero warnings, and both systemd managers report no failed units. See the [review record](reviews/niri-spiderverse.md).

### Previous graphite wallpaper verification

The folded graphite wallpaper was designed and separately approved by Opus 5.5 at medium effort using actual VM screenshots. Ghostty shows the bright fold as a soft band through its glass. The control center's heavier tint keeps that effect subtler; its user card also draws a wallpaper-derived image of its own. Text remains readable. Rendered 16:10 and 3:2 crops preserve the composition, but physical display brightness, banding and Noctalia's actual 3:2 crop remain untested.

Live testing also caught Noctalia retaining a replaced image in its path-based cache. Source-hashed render filenames and rendering before config publication allowed normal reloads to pick up new artwork. Resize and restore runs passed, followed by a full `changed=0` rerun and native validation with zero warnings. See the [wallpaper review record](reviews/niri-wallpaper.md) for details and limits. Those render-size checks apply to the previous SVG wallpaper; the current raster is installed directly.

## Sources

- Niri v26.04 wiki: [Window rules (blur, `background-effect`)](https://github.com/niri-wm/niri/blob/v26.04/docs/wiki/Configuration:-Window-Rules.md), [Layer rules](https://github.com/niri-wm/niri/blob/v26.04/docs/wiki/Configuration:-Layer-Rules.md), [Include](https://github.com/niri-wm/niri/blob/v26.04/docs/wiki/Configuration:-Include.md), [Outputs](https://github.com/niri-wm/niri/blob/v26.04/docs/wiki/Configuration:-Outputs.md), [Key bindings](https://github.com/niri-wm/niri/blob/v26.04/docs/wiki/Configuration:-Key-Bindings.md), [Xwayland](https://github.com/niri-wm/niri/blob/v26.04/docs/wiki/Xwayland.md), [Important software](https://github.com/niri-wm/niri/blob/v26.04/docs/wiki/Important-Software.md)
- Noctalia v5.4.1: [repository and user docs](https://github.com/noctalia-dev/noctalia/tree/v5.4.1/docs/user), [`example.toml`](https://github.com/noctalia-dev/noctalia/blob/v5.4.1/example.toml), [packaging notes](https://github.com/noctalia-dev/noctalia/blob/v5.4.1/PACKAGING.md). The installed `noctalia msg --help` was used for IPC.
- [oo7](https://github.com/linux-credentials/oo7), Fedora 45's Secret Service and PAM module
- [GDM session selection](https://gitlab.gnome.org/GNOME/gdm/-/blob/main/daemon/gdm-session-settings.c) via [AccountsService](https://gitlab.freedesktop.org/accountsservice/accountsservice)
- Zed: [official Linux installation](https://zed.dev/docs/linux), [pinned first-install release](https://github.com/zed-industries/zed/releases/tag/v1.27.0). Bitwarden: [desktop feature support](https://bitwarden.com/help/desktop-app-feature-support/), [Flathub manifest](https://github.com/flathub/com.bitwarden.desktop) and [native unlock policy](https://github.com/bitwarden/clients/blob/main/apps/desktop/resources/com.bitwarden.desktop.policy).
- [Tailscale's Fedora repository](https://pkgs.tailscale.com/stable/fedora/tailscale.repo) and [Linux setup](https://tailscale.com/docs/install/linux). The RPM key fingerprint is pinned in the role.
- [adw-gtk3](https://github.com/lassekongo83/adw-gtk3), [Papirus](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme)
