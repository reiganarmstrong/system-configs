# Fedora desktop

Ansible configures Fedora Workstation's GNOME with the [PaperWM](https://github.com/paperwm/PaperWM) scrolling window manager, stock GNOME styling and macOS-style icons. The Fedora VM is the rehearsal for installing the same desktop on a Framework laptop after the Fedora installer finishes.

This page covers the GNOME profile (`desktop.yml`). A second profile, `niri.yml`, sets up the Niri scrolling compositor with the Noctalia shell in a monochrome Graphite look, alongside GNOME. It reuses this profile's apps and shell setup. See [NIRI.md](NIRI.md).

The `desktop` role owns the GNOME packages, PaperWM, icons, wallpaper, key bindings, portals, audio services and default login session. Both the VM and native laptop execute that role. Changes made while experimenting belong in the role and are reapplied with Ansible.

## Native Fedora installation

Install Fedora 45 Workstation or newer and create your normal user account with administrator privileges. Log in as that user and install the bootstrap tools.

```bash
sudo dnf install -y git python3-pip
git clone https://github.com/reiganarmstrong/system-configs.git
cd system-configs/fedora
./bootstrap.sh
.local/ansible/bin/ansible-playbook desktop.yml --ask-become-pass
```

The repository is public on GitHub, so cloning needs no credentials. Run Ansible as your normal user. It configures that account by default. Use `-e desktop_user=NAME` to select another existing account.

The bootstrap script installs Ansible Core 2.22.0 and the collection versions in `requirements.yml` into ignored `.local/` directories. Ansible 2.22 supports Fedora 45's Python 3.15. Older controller versions fail before running desktop tasks.

Reboot after the first run. The GNOME session starts with PaperWM, Dash to Dock and Quick Settings Fit enabled. Automatic login is disabled for native installations. Subsequent runs use the same command; they add missing extensions and shortcuts without removing ones you enabled yourself.

Fedora 45 is the tested starting release. Packages track Fedora's repositories, so later runs can install newer dependency versions. This repository reproduces the configuration and package selection rather than an immutable OS image.

## Appearance

- **GNOME Shell and GTK theme:** GNOME's stock Adwaita in dark mode. No custom shell or GTK theme is installed, so the shell, GTK 3, libadwaita and Flatpak apps all use GNOME's own styling and window buttons.
- **Icons:** [WhiteSur](https://github.com/vinceliuice/WhiteSur-icon-theme) `WhiteSur-dark`, pinned to `desktop_whitesur_revision` (`roles/desktop/tasks/icons.yml`).
- **Top bar:** solid black, including in the overview. PaperWM normally makes the bar translucent, so its top bar styling (`disable-topbar-styling`) is turned off, and `roles/desktop/files/paperwm-user.css` is installed as `~/.config/paperwm/user.css`. PaperWM reads that file only when it is enabled, so Ansible disables and re-enables PaperWM when the file changes.
- **Quick settings:** the same `paperwm-user.css` makes the quick settings menu compact: 165 × 66 px tiles with 20 px gaps, 20 px rounded corners, a uniform faint light rim, and a slightly lighter fill than the menu. GNOME sizes the menu's columns from every toggle, including hidden ones that never pick up `user.css`, so the role also installs a small local extension, Quick Settings Fit (`roles/desktop/files/quick-settings-fit`), that sizes them from visible toggles only. Without it, the menu can't shrink below GNOME's stock width.
- **Dock:** Fedora's Dash to Dock package, at the bottom, with 48 px icons on a translucent muted gray (`rgb(94,92,100)`) at 35% opacity. The dock stays hidden, even on an empty desktop, and appears only when the pointer touches the bottom edge of the screen. It doesn't require pushing against the edge (`require-pressure-to-show` is off), because VNC's absolute pointer can't push past the screen edge.
- **Windows:** GNOME's default window buttons, Inter as the interface font, dark mode with a blue accent, and hot corners disabled.
- **Wallpaper:** `roles/desktop/files/wallpaper.svg`.

## Packages and apps

The playbook uses Fedora's own package managers and lists everything in `roles/desktop/defaults/main.yml`:

- **dnf** (`desktop_packages`) installs the desktop, system services and command-line tools. These are the packages Fedora tests together, and dnf is the only manager that can safely own the system layer.
- **Flatpak from Flathub** (`desktop_flatpaks`) installs desktop apps that Fedora doesn't package. Zen Browser (`app.zen_browser.zen`) is installed this way, which is Zen's recommended Linux install. Flathub apps run sandboxed and update independently of the OS. `roles/desktop/tasks/apps.yml` adds the Flathub remote system-wide and enables it, because Fedora Workstation can ship it disabled.

Developer tools come from the same places:

- **Node.js 24, npm, pnpm and uv** come from Fedora's packages. `nodejs24-bin` and `nodejs24-npm-bin` make Node 24 (the server's major version) own `node`, `npm` and `npx` instead of Fedora's default Node 22. Fedora's pnpm is 10.x. It switches to the version a project pins in its `packageManager` field, so projects that require pnpm 11 still use 11.
- **Claude Code** comes from Anthropic's signed dnf repository. `apps.yml` imports the key only if its fingerprint matches the one Anthropic publishes. `desktop_claude_code_channel` selects `latest`, the native installer's default, or `stable`, which runs about a week behind. dnf installs don't update themselves; `sudo dnf upgrade` picks up new versions.
- **Ghostty** is the default terminal. It isn't in Fedora or on Flathub, so it comes from the community `scottames/ghostty` COPR that Ghostty's install docs point Fedora users to. That build comes from a third party, not from Fedora or the Ghostty project. On Linux, Ghostty uses GTK4 and libadwaita, so it matches other GNOME apps. foot, the other option considered, would draw its own plain title bar under GNOME. Super+T opens Ghostty. `~/.config/xdg-terminals.list` makes it the terminal that `xdg-terminal-exec` (and therefore GLib) uses for terminal apps. `roles/desktop/files/ghostty.config` sets Catppuccin Mocha, the palette the Starship prompt was designed for, with a neutral `#212121` background, and `ssh-env`. With `ssh-env`, SSH sessions advertise `xterm-256color` instead of `xterm-ghostty`, a terminal type most servers don't recognize. Fedora Workstation's own terminal stays installed as a fallback.
- **T3 Code** has no RPM or Flatpak. Ansible downloads the official AppImage once to `~/Applications/T3-Code.AppImage`, checks it against `desktop_t3code_sha256`, and adds a launcher entry with the app's icon. After that the app updates itself in place, and Ansible never replaces a newer copy. The AppImage includes its own FUSE support, so no extra FUSE packages are needed. The server's `t3` alias (`npx --yes t3@nightly`) works too, through Node 24.

`sudo dnf upgrade` and `flatpak update` update the two sets, and GNOME Software updates both. Starship and the zsh plugins are the exceptions: they come from pinned upstream releases (see Shell).

Homebrew on Linux was tried and left out. It can't own the system layer, and its Linux casks install apps as AppImages, which lack Flatpak's sandboxing and integrate less fully with the desktop. Putting its `bin` directory ahead of `/usr/bin` also shadows Fedora's own `python3`, `pkg-config` and similar tools, and installing the same tool through both brew and dnf leads to version confusion. Homebrew mainly makes sense on image-based Fedora variants such as Silverblue, where dnf can't add packages freely.

Sandboxed browsers can need extra setup for features that talk to other desktop programs, such as a desktop password manager's browser integration. Check Zen's Flathub page if you rely on one.

## Shell

`roles/desktop/tasks/shell.yml` copies the Ubuntu server's zsh setup and makes zsh the login shell. It takes effect in new terminals and the next login.

- **oh-my-zsh** with the `git`, `zsh-autosuggestions` and `zsh-syntax-highlighting` plugins, each pinned to the commit the server runs (`desktop_ohmyzsh_revision`, `desktop_zsh_plugins`). oh-my-zsh's self-updater is disabled so the pin holds; raise the pins to update.
- **Starship** `desktop_starship_version` from the upstream release, checked against `desktop_starship_sha256`, because Fedora doesn't package it. It is installed under `/opt/fedora-desktop/` and linked into `/usr/local/bin`. The prompt is the server's Catppuccin `roles/desktop/files/starship.toml`, which needs no Nerd Font.
- **`~/.zshrc` and `~/.zshenv`** come from `roles/desktop/templates/` with the server's aliases, functions, `EDITOR=vim` and PATH entries. Ansible overwrites them, so put laptop-only additions in `~/.zshrc.local`, which `~/.zshrc` sources last. The server's `BROWSER=none` is left out because it would stop tools from opening the desktop browser.

The `sleep` alias suspends the machine (`sudo systemd-run --on-active=5s systemctl suspend && exit`). It only applies in interactive shells; scripts still get the real `sleep`.

## PaperWM

PaperWM, pinned to `desktop_paperwm_revision`, is cloned into `~/.local/share/gnome-shell/extensions`. Ansible stops if the installed GNOME Shell major version isn't listed in the pinned PaperWM's `metadata.json`. After a Fedora upgrade, raise the pin to a release that supports the new GNOME version. The role sets 12 px gaps and margins and the wallpaper as the workspace background. PaperWM's focus border is turned off (`selection-border-size` 0). Focus uses PaperWM's default mode, which scrolls only as far as needed so side-by-side windows stay in place. Super+Shift+C switches a workspace to center mode, which scrolls each focused window to the middle.

| Keys | Action |
| --- | --- |
| Super+T | Terminal (Ghostty) |
| Super+Space | GNOME overview and app search |
| Super+Left / Super+Right | Focus the window to the left or right |
| Super+Ctrl+Left / Super+Ctrl+Right | Move the window left or right in the strip |
| Super+R | Cycle the window width |
| Super+I / Super+O | Stack the next window into this column / pop it back out |
| Super+Return | New window of the focused app |
| Super+Backspace | Close the window |
| Super+Escape | Toggle the floating scratch window |
| Super+Shift+T | PaperWM's "take window" (moved from Super+T) |

Input-source switching moves to Super+Alt+Space so Super+Space can open the overview. The rest of PaperWM's bindings are its upstream defaults and are listed in its settings (Extensions → PaperWM).

## Display

The VM output is 3840×2160 at 60 Hz with 2× scaling, giving a 1920×1080 logical workspace. `desktop_output_mode` and `desktop_output_scale` control those values when `desktop_output` names a connector. Native installs leave `desktop_output` empty, so GNOME picks the panel's mode and scaling itself.

In the VM, `~/.local/bin/configure-vm-display` writes the layout to `~/.config/monitors.xml` for future logins and applies it to the running session temporarily. A persistent apply through Mutter's D-Bus API would open GNOME's "Keep these display settings?" prompt and revert after 20 seconds if no one confirmed it.

## Rehearsal VM on Ubuntu

Install Git and Python's venv support on the Ubuntu host with `sudo apt install git python3-venv`. Clone this repository and run `./bootstrap.sh`. Before the first VM run, create its VNC password file with this private prompt. Classic VNC authentication uses eight characters. Choose exactly eight printable ASCII characters without spaces.

```bash
python3 - <<'PY'
import getpass
import os
from pathlib import Path

password = getpass.getpass('Choose an 8-character VNC password: ')
if len(password) != 8 or not all('!' <= character <= '~' for character in password):
    raise SystemExit('Use exactly 8 printable ASCII characters without spaces.')
path = Path('.local/vnc-password')
descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
with os.fdopen(descriptor, 'w') as output:
    output.write(password)
PY
```

This file stays in ignored `.local/` state. The playbook redacts password-bearing tasks and stores libvirt's generated definitions with root-only permissions. Then run the VM playbook as your normal host user.

```bash
.local/ansible/bin/ansible-playbook vm.yml --ask-become-pass
```

The VM playbook installs QEMU/libvirt, downloads the checksum-pinned Fedora 45 cloud image, creates a 60 GiB expandable disk, assigns four virtual CPUs and 8 GiB RAM, and starts the guest on libvirt's default NAT network. It then runs the same `desktop` role used by `desktop.yml` on a native laptop.

The cloud image only bootstraps the account and SSH access. All desktop installation and configuration happens in Ansible. VM administration uses a generated SSH key and passwordless sudo inside the guest. Private keys, known hosts and the generated inventory stay in ignored `.local/` state. Guest disks and seed files live under `/var/lib/libvirt/images/fedora-paperwm/`.

VM-only settings enable automatic login, disable screen locking and idle sleep, select the 4K virtual display, and install the QEMU guest agent. The virtual GPU uses VirtIO 3D and headless EGL through the host's Arc GPU at `/dev/dri/renderD128`. Native installations use their physical display and normal graphics defaults. This VM does not validate laptop Wi-Fi, suspend, fingerprint, battery, touchpad gestures or display scaling.

To apply a desktop change to the VM, run this from the Ubuntu host.

```bash
.local/ansible/bin/ansible-playbook -i .local/vm.yml desktop.yml
```

Run the same command again to check that it reports no unintended changes. To check the native configuration without applying changes, add `--check --diff` to the native command on an already configured Fedora installation.

`vars/vm.yml` contains the VM resources and image checksum. Changes to virtual hardware or the VNC password trigger a graceful VM shutdown and definition update on the next VM playbook run. Shut down the guest before increasing its disk size. Cloud-init account changes require a fresh VM. The playbook preserves existing guest disks and does not rebuild them on another run. A new host must have `/dev/kvm`, hardware virtualization enabled and a GPU render device suitable for headless EGL.

## Connect from the Mac

Connect Tailscale on the Mac to the same tailnet as the Ubuntu host. The server's Tailscale address is `100.79.178.44`, and its MagicDNS name is `pc.taila028da.ts.net`. Forward the VM console through SSH over Tailscale.

```bash
ssh -N \
  -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=15 \
  -o ServerAliveCountMax=3 \
  -L 127.0.0.1:5901:127.0.0.1:5901 \
  reagan@pc.taila028da.ts.net
```

Keep that terminal running. In another terminal, run `open vnc://127.0.0.1:5901` to open macOS Screen Sharing. Enter the VNC password chosen during VM setup when Screen Sharing prompts. Another VNC viewer can connect to `127.0.0.1` on port `5901`. The console listens only on the Ubuntu host's loopback address, and SSH carries the connection over Tailscale. On the home LAN, `192.168.1.215` can also be used as the SSH server address. [SSH over Tailscale](https://tailscale.com/docs/reference/ssh-over-tailscale)

Super is Command when the VNC viewer forwards the Mac Command key as Super. macOS Screen Sharing intercepts many Command shortcuts, so use TigerVNC to try PaperWM's keys.

For testing the Linux shortcuts from macOS, TigerVNC Viewer supports capturing system keys in full screen. Keep the SSH tunnel running and connect TigerVNC to `127.0.0.1::5901`. In its Input options, enable “Always send all keyboard input in full screen” and use full-screen mode. Allow TigerVNC under macOS System Settings → Privacy & Security → Accessibility when prompted. Current TigerVNC maps Command to Super and Option to Alt. Control+Option releases the keyboard capture, and Control+Option+M opens the viewer menu. This client setup requires verification on the Mac. [TigerVNC viewer options](https://tigervnc.org/doc/vncviewer.html), [Mac keyboard capture guidance](https://github.com/TigerVNC/tigervnc/issues/2024), [Mac modifier mapping](https://github.com/TigerVNC/tigervnc/blob/v1.16.2/vncviewer/KeyboardMacOS.mm)

QEMU VNC carries the VM console. Audio forwarding and a shared clipboard are not configured.

Manage the VM on Ubuntu with libvirt.

```bash
sudo virsh shutdown fedora-paperwm
sudo virsh start fedora-paperwm
sudo virsh domifaddr fedora-paperwm
```

The VM does not automatically start when the Ubuntu host reboots. Run the VM playbook again if DHCP changes its address so that `.local/vm.yml` is refreshed.

## Verification

On November 4, 2026, the laptop path was also tested from a fresh Fedora 45 Workstation install in a separate VM. The account was an administrator with a password, and auto-login was off, as on the Framework. After logging in at GDM and skipping the welcome tour, the test followed the "Native Fedora installation" steps exactly: `sudo dnf install -y git python3-pip`, `git clone` over HTTP, `./bootstrap.sh`, then `ansible-playbook desktop.yml --ask-become-pass`.

The first run found one bug: the `community.general.copr` module needs the dnf 4 Python bindings, which Workstation doesn't install, and the rehearsal VM had them only by chance. The Ghostty COPR is now defined with `yum_repository` and a fingerprint-pinned key. After that fix the playbook completed. After a reboot and password login, all of the following were confirmed:

- PaperWM, User Themes and Dash to Dock active
- WhiteSur shell, GTK and libadwaita theming
- black top bar and dark auto-hiding dock
- zsh with oh-my-zsh and Starship as the login shell
- Ghostty on Super+T and as the `xdg-terminal-exec` default
- Zen from Flathub, Claude Code from Anthropic's dnf repo, T3 Code in `~/Applications`
- Node 24, pnpm and uv

A second run reported zero changes.

On November 4, 2026, `desktop.yml` completed against the Fedora 45 VM with GNOME Shell 51.1, and a repeat run reported zero changes. PaperWM, User Themes and Dash to Dock were active, and `WhiteSur-Dark-solid` was selected for both the shell and GTK, and the libadwaita stylesheet in `~/.config/gtk-4.0/` loaded in Text Editor without CSS errors. After a guest reboot, GDM logged in automatically and the session came up at 3840×2160 at 60 Hz with 2× scaling from the saved `monitors.xml`. Physical Framework hardware still requires testing on that device.

The WhiteSur shell and GTK theme and the User Themes extension were removed after these tests. The desktop now uses GNOME's stock Adwaita theme with WhiteSur icons.

Check VNC authentication against the running VM from the Ubuntu host with the default local password file.

```bash
.local/ansible/bin/python tests/check_vnc_auth.py
```

The VM account has no password, so automatic login can't unlock the "Login" keyring (Fedora 45's `oo7-daemon`). The first app that stores a secret in each session, such as T3 Code, shows an unlock prompt and waits until it is answered. Leave the field empty and click Unlock. A normal password login on the laptop unlocks the keyring automatically. Record any desktop settings chosen during experiments in the shared role before relying on them for the laptop installation.

## Sources

[PaperWM](https://github.com/paperwm/PaperWM), [WhiteSur icon theme](https://github.com/vinceliuice/WhiteSur-icon-theme), [Dash to Dock](https://micheleg.github.io/dash-to-dock/).

The Fedora 45 cloud image checksum was verified against Fedora's signed release manifest using Fedora's published signing keys. [Fedora cloud downloads](https://fedoraproject.org/cloud/download/), [Signing keys](https://fedoraproject.org/security/)
