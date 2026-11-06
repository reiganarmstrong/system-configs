# Fedora with Niri and Noctalia

`niri.yml` turns a Fedora 45+ install into a [Niri](https://github.com/niri-wm/niri) scrolling-tiling session with the [Noctalia](https://github.com/noctalia-dev/noctalia) v5 shell, in a monochrome look called Graphite. It's a separate profile from `desktop.yml` (GNOME with PaperWM). It reuses that profile's app and shell tasks, and GNOME stays installed and selectable at the login screen.

Niri 26.04 or newer is required for background blur and for optional config includes, and Noctalia must be the native v5 shell. Fedora 45 ships both (`niri-26.04`, `noctalia-5.4.1`), so the role refuses older releases.

## Install

Start from Fedora 45 Workstation (or Everything with GDM), with a normal administrator account that has a password, and log in as that account.

```bash
sudo dnf install -y git python3-pip
git clone https://github.com/reiganarmstrong/system-configs.git
cd system-configs/fedora
./bootstrap.sh
.local/ansible/bin/ansible-playbook niri.yml --ask-become-pass
```

Reboot, enter your password at GDM, and you land in Niri. Use `-e niri_user=NAME` to configure another existing account. To preview changes on an already configured machine, add `--check --diff`.

Tailscale is installed and started, with your account set as its operator, as on NixOS. Run `tailscale up` once after installation to sign this machine into your tailnet. Ansible never authenticates or resets an existing connection. Set `-e niri_tailscale_enabled=false` to skip its setup.

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
| Super+Space | Noctalia launcher |
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
| Super+R, Super+− / = | Cycle column width presets (⅓, ½, ⅔), narrow or widen by 10% |
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

Super+drag moves a window, and Super+right-drag resizes it (Niri defaults). Shell shortcuts go through `noctalia msg`, Noctalia's IPC. `tests/check_niri_keybinds.py` checks every one against the installed Noctalia (see [Testing](#testing)).

Click the time in the top-center notch to open the control center. The launcher button is at the start of the auto-hiding dock. Launcher, clipboard, control center, wallpaper and session panels open beneath the notch; the keyboard shortcuts above still work.

## Graphite

The NixOS desktop uses a hand-built Quickshell bar. Graphite drops that look on purpose: no accent hue, no colored workspace pills. It's black, white and grays, with chrome as frosted glass over the wallpaper. Color appears only where it carries meaning: red for errors and urgent windows, amber for warnings, green for success in the terminal.

The dock, notifications, OSD, panels and window switcher are translucent with real background blur. The notch is near-opaque instead, for the rendering reason below. App windows stay opaque, so text sits on a solid surface. Ghostty's 84%-opaque background blurs the wallpaper behind it using Niri's default xray blur.

| Token | Value | Used for |
| --- | --- | --- |
| Surface | `#0a0a0b` | Shell and terminal background, wallpaper fill |
| Surface variant | `#18181a` | Cards, input fields |
| Hover | `#26262a` | Hover and pressed states |
| Outline | `#3a3a3f` | Separators, selections |
| Text | `#ececee` | Primary text |
| Muted text | `#a3a3a9` | Secondary labels |
| Primary | `#f2f2f3` | Focus, active items (white on black instead of an accent color) |
| Error | `#ff5c5c` | Errors, urgent window border |
| Warning | `#d4a95a` | Warnings (terminal yellow, Starship's warning style) |
| Active border | `#ffffff5c` | 1 px focused-window hairline |
| Inactive border | `#ffffff1a` | 1 px hairline on other windows |

These values live in `roles/niri/files/Graphite.json` (Noctalia's palette, including the 16 terminal colors), `ghostty.config`, `starship.toml`, `btop-graphite.theme` and `templates/config.kdl.j2`.

- **Geometry.** 12 px gaps and 14 px corners on windows, 18 px on the dock. The notch is a 28 px pill, centered 3 px below the top edge. A soft drop shadow and a hairline border mark the focused window. Niri's border does not draw behind Ghostty's translucent background.
- **Blur.** Niri 26.04's `blur` block uses 3 passes, a small offset, a little noise against banding and 60% saturation, so colorful windows behind the glass don't tint it. Noctalia's layers and floating windows use non-xray blur, so they blur the windows that are really behind them. Niri marks non-xray blur experimental.
- **Type.** Inter for the UI and JetBrains Mono for terminals and code, from Fedora's packages.
- **Wallpaper.** `roles/niri/files/wallpaper.svg` draws two overlapping graphite folds with lit edges, soft cast shadows, faint pleats and fine grain. The brightest edges cross behind the centered panels, giving their blur a visible light-to-dark transition. The upper area stays quiet behind the notch. The SVG has no external assets or fonts. Noctalia only loads raster images, so Ansible renders it to a 3840×2400 PNG with `rsvg-convert`. This is 16:10; Noctalia crops it for the Framework 13's 3:2 display. `niri_wallpaper_size` controls the render dimensions. The PNG filename includes those dimensions and a source hash, so changing either generates a fresh render and invalidates Noctalia's image cache.
- **Lock screen.** A blurred, darkened copy of the wallpaper with the clock, drawn by Noctalia.
- **GTK and Qt.** libadwaita apps get dark mode and the Slate accent (libadwaita's gray) from dconf. GTK 3 apps get `adw-gtk3-dark`, a port of the libadwaita look. Qt apps follow GTK through `QT_QPA_PLATFORMTHEME=gtk3`. There's no custom app CSS. Overriding libadwaita's stylesheet tends to break with each GNOME release. Windows use server-side decorations where apps support them, and VSCodium hides its own window buttons.
- **Terminal.** Ghostty and Starship replace the GNOME profile's Catppuccin with the Graphite palette. Starship keeps the server's layout and its ASCII-only symbols. btop gets a matching theme with a transparent background. Fastfetch is configured, with an optional greeting for first-level interactive shells.
- **Icons.** Papirus-Dark, whose flat icons sit better on gray glass than WhiteSur's glossy ones.

### Notch

One compact row shows workspaces, media, time, network, volume, Bluetooth, battery, notifications and the tray. Widgets with no device or content hide themselves. The VM usually shows just workspaces, time, wired network and volume, about 165 px wide. The row sizes to its content on every output, without connector-specific widths or layout scripts. Network names stay in the native tooltip, so a long SSID cannot stretch the row. The battery shows its percentage inside a graphical battery when one is present.

Click the time for the control center, or use each widget's native action for its own controls. Connection details are available in the network tooltip and Network tab. Floating panels open 6 px below the reserved bar strip. Panel slide-down, hover highlights and tooltips use Noctalia's native animation settings, including `[shell.animation] enabled = false` for reduced motion.

The [reference video's notch](https://www.youtube.com/watch?v=cLB2eaXrrk4) grows into a larger surface. This configuration keeps a steady row. A native center-lane accordion moved the clock out from under the pointer, so waiting before a click could select a workspace instead. Opus's design review rejected that interaction. Keeping the row visible also makes connection and battery status readable without a hover. Panels remain separate animated cards; there is no custom morphing surface.

The implementation is one native `capsule_group` inside a transparent bar. The capsule uses Graphite's surface color at 92% opacity and a 1 px outline. Bar blur and shadow are off because they would cover the full bar area even where its background is transparent. The panels retain their own glass and blur. No plugin, shell fork, custom animation code or scripts tracking desktop state are installed.

The transparent host bar reserves 34 logical pixels across the top, passes empty space through, and uses the `top` layer so fullscreen windows cover it. Its visible capsule is small, but the reserved strip is still full width. These are stock Noctalia 5.4.1 behaviors. On upgrades, run `noctalia config validate` and review any warnings, especially for `capsule_group`, widget options and floating panel placement. All of those settings remain in one template.

## Services

Noctalia is a full shell, so most session services come from it. Niri's weak dependencies (waybar, fuzzel, swaylock, mako-style tools, gnome-keyring) are skipped (`install_weak_deps: false`) so nothing runs twice.

| Need | Provided by |
| --- | --- |
| Login | GDM with a password and the `niri` Wayland session. Automatic login is off. |
| Bar, launcher, dock, tray, OSD, notifications | Noctalia, started by Niri (`spawn-at-startup`). It's the only notification daemon. |
| Lock screen | Noctalia, checked against the `login` PAM stack. It locks before suspend. |
| Idle | Noctalia: lock at 5 min, displays off at 6 min, suspend at 15 min (`niri_idle_*_seconds`, 0 disables). Apps that inhibit idle, such as video players, are respected. |
| Polkit prompts | Noctalia's built-in agent (`polkit_agent = true`). |
| Keyring | Fedora 45's `oo7-daemon`, started as a dependency of `niri.service` and stopped with the graphical session. GDM's vendor `pam_oo7` stack hands it the login password. Fedora ships the daemon disabled, so installing its package alone is insufficient. A user-level `niri-portals.conf` routes the Secret portal to `oo7-portal` in Niri sessions only. VSCodium uses libsecret. |
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

- **VSCodium** from its upstream RPM repository. The signing key is imported only if its fingerprint is `1302 DE60 2318 89FE 1EBA CADC 5467 8CF7 5A27 8D9C`, and both packages and repository metadata are signature-checked (`gpgcheck`, `repo_gpgcheck`). Ansible adds two settings only when they're missing and never changes ones you set: `password-store` in `~/.vscode-oss/argv.json` and `window.controlsStyle` in `settings.json`.
- **Nautilus** and **GNOME Calendar** with GNOME Online Accounts and `evolution-ews-core`, so Exchange/Microsoft 365 calendars work. Add accounts in the standalone Online Accounts app (`gnome-online-accounts-gtk`), which replaces the GNOME Settings panel outside GNOME.
- **btop** and **fastfetch**.
- **Disks**, **Passwords and Keys** (`seahorse`), **Print Settings** (`system-config-printer`) and **PulseAudio Volume Control** (`pavucontrol`) retain the NixOS management tools. Noctalia replaces Blueman's connection/pairing controls, so its competing applet is not installed. Niri output settings replace `wdisplays`, which uses a different compositor protocol. Changes to connected displays go in `niri_outputs` or `~/.config/niri/local.kdl`.

## Personalizing

Ansible rewrites the files it owns on every run, so edits to them don't survive. Each one has an override that Ansible never touches:

| Owned by Ansible | Put your changes in |
| --- | --- |
| `~/.config/niri/config.kdl` | `~/.config/niri/local.kdl`, included last, so it can add binds, outputs and window rules or override earlier settings |
| `~/.config/noctalia/00-fedora-niri.toml` | Noctalia's Settings window (Super+,), which saves to `~/.local/state/noctalia/settings.toml`. Or a later-sorting file such as `~/.config/noctalia/50-mine.toml`. Both take precedence. |
| `~/.config/ghostty/config` | `~/.config/ghostty/local` |
| `~/.zshrc` | `~/.zshrc.local` |
| `~/.config/starship.toml`, btop's theme lines, fastfetch's config | No override; change them in the role |

Niri and Noctalia reload their config while running, so a rerun takes effect without logging out. Both configs are checked before they're written (`niri validate`, `noctalia config validate`), so a bad template can't break a running session.

Reordering bar widgets in Noctalia's Settings window saves lane and capsule-group overrides in `~/.local/state/noctalia/settings.toml`. Those override the role, and arrays replace rather than merge. If a later notch change does not appear, inspect the saved `[bar.main]` lanes and `capsule_group` entries, plus any widget overrides. Remove only the overrides you want the role to manage; other personal settings can stay.

Variables in `roles/niri/defaults/main.yml`:

- `niri_outputs` pins a display's mode, scale and position. By default nothing is pinned, and Niri picks each display's preferred mode and a fractional scale from its DPI. That gives the Framework 13's 2880×1920 panel a sensible scale with no host-specific connector name in the repo. To pin it, run `niri msg outputs` in the session and copy the name, then set for example `niri_outputs: [{name: eDP-1, scale: 1.75}]`. A monitor can be named by make, model and serial so it follows the cable.
- `niri_keyboard_layout` and `niri_keyboard_options` set the XKB layout, such as `us` with `ctrl:nocaps`.
- `niri_idle_lock_seconds`, `niri_idle_screen_off_seconds` and `niri_idle_suspend_seconds`.
- `niri_dock_pinned` lists the dock's apps by desktop entry id.
- `niri_default_session` (see above).
- `niri_tailscale_enabled` installs and starts Tailscale by default. Turning it off skips management; it does not uninstall or disconnect an existing installation.

## Shared state between profiles

`desktop.yml` and `niri.yml` configure the same account, and some settings exist only once. Whichever playbook ran last decides them:

- dconf's `org.gnome.desktop.interface` keys: color scheme, accent, GTK theme, icon theme and fonts. After `niri.yml`, GNOME uses the Slate accent and Papirus icons until `desktop.yml` runs again.
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

- Clicking the time immediately or after a 500 ms hover opens the control center in both cases. Clicking an empty workspace dot after a 500 ms hover selects that workspace when a second workspace exists.
- Control center, launcher, clipboard, session and wallpaper panels open below the notch. Screenshots at scales 1, 1.25 and 1.5 show the capsule and control center fitting on screen. The final layout also renders with native animations disabled, and the temporary override was removed afterward.
- The rendered configuration passes `noctalia config validate` with zero warnings. The final full playbook rerun reports `ok=65 changed=0 failed=0`; system and user managers report no failed units.

The VM has no battery, Wi-Fi adapter or Bluetooth device. Their appearance and tooltips still need a hardware check. Multi-monitor placement and the estimated fully populated laptop width have not been measured. The [notch review record](reviews/niri-notch.md) explains the design tradeoffs and resolved findings.

### Wallpaper verification

The folded graphite wallpaper was designed and separately approved by Opus 5.5 at medium effort using actual VM screenshots. Ghostty shows the bright fold as a soft band through its glass. The control center's heavier tint keeps that effect subtler; its user card also draws a wallpaper-derived image of its own. Text remains readable. Rendered 16:10 and 3:2 crops preserve the composition, but physical display brightness, banding and Noctalia's actual 3:2 crop remain untested.

Live testing also caught Noctalia retaining a replaced image in its path-based cache. Source-hashed render filenames and rendering before config publication now allow normal reloads to pick up new artwork. Resize and restore runs passed, followed by a full `changed=0` rerun and native validation with zero warnings. See the [wallpaper review record](reviews/niri-wallpaper.md) for details and limits.

## Sources

- Niri v26.04 wiki: [Window rules (blur, `background-effect`)](https://github.com/niri-wm/niri/blob/v26.04/docs/wiki/Configuration:-Window-Rules.md), [Layer rules](https://github.com/niri-wm/niri/blob/v26.04/docs/wiki/Configuration:-Layer-Rules.md), [Include](https://github.com/niri-wm/niri/blob/v26.04/docs/wiki/Configuration:-Include.md), [Outputs](https://github.com/niri-wm/niri/blob/v26.04/docs/wiki/Configuration:-Outputs.md), [Key bindings](https://github.com/niri-wm/niri/blob/v26.04/docs/wiki/Configuration:-Key-Bindings.md), [Xwayland](https://github.com/niri-wm/niri/blob/v26.04/docs/wiki/Xwayland.md), [Important software](https://github.com/niri-wm/niri/blob/v26.04/docs/wiki/Important-Software.md)
- Noctalia v5.4.1: [repository and user docs](https://github.com/noctalia-dev/noctalia/tree/v5.4.1/docs/user), [`example.toml`](https://github.com/noctalia-dev/noctalia/blob/v5.4.1/example.toml), [packaging notes](https://github.com/noctalia-dev/noctalia/blob/v5.4.1/PACKAGING.md). The installed `noctalia msg --help` was used for IPC.
- [oo7](https://github.com/linux-credentials/oo7), Fedora 45's Secret Service and PAM module
- [GDM session selection](https://gitlab.gnome.org/GNOME/gdm/-/blob/main/daemon/gdm-session-settings.c) via [AccountsService](https://gitlab.freedesktop.org/accountsservice/accountsservice)
- [VSCodium RPM repository](https://github.com/VSCodium/vscodium#install) and its [signing key](https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo). The fingerprint was checked against a good signature on the repository's `repomd.xml.asc`.
- [Tailscale's Fedora repository](https://pkgs.tailscale.com/stable/fedora/tailscale.repo) and [Linux setup](https://tailscale.com/docs/install/linux). The RPM key fingerprint is pinned in the role.
- [adw-gtk3](https://github.com/lassekongo83/adw-gtk3), [Papirus](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme)
