# Fedora desktop

Ansible configures Fedora with Niri and Noctalia. The Fedora VM is the rehearsal for installing the same desktop on a Framework 13 Pro after the Fedora installer finishes.

The `desktop` role owns the desktop packages, Niri configuration, Noctalia startup, key bindings, desktop portals, audio packages and default login session. Both the VM and native laptop execute that role. Changes made while experimenting belong in the role and are reapplied with Ansible.

## Native Fedora installation

Install Fedora 45 Workstation or newer and create your normal user account with administrator privileges. Log in as that user and install the bootstrap tools.

```bash
sudo dnf install -y git python3-pip
git clone reagan@100.79.178.44:/home/reagan/documents/github/fedora-desktop
cd fedora-desktop
./bootstrap.sh
.local/ansible/bin/ansible-playbook desktop.yml --ask-become-pass
```

The clone command reads this Git repository over SSH from the Ubuntu server's Tailscale address. Connect the laptop to the same tailnet first. Substitute a Git hosting URL if it is published later. Run Ansible as your normal user. It configures that account by default. Use `-e desktop_user=NAME` to select another existing account.

The bootstrap script installs Ansible Core 2.22.0 and the collection versions in `requirements.yml` into ignored `.local/` directories. Ansible 2.22 supports Fedora 45's Python 3.15. Older controller versions fail before running desktop tasks.

Reboot after the first run, then select Niri from the login screen's session menu if needed. Automatic login is disabled for native installations. Subsequent runs use the same command. Configuration changes to Niri normally reload while the session is running.

Fedora 45 is the tested starting release. Packages track Fedora's repositories, so later runs can install newer dependency versions. This repository reproduces the configuration and package selection rather than an immutable OS image.

## Appearance and display

The shared desktop role configures a macOS-inspired dark palette with blue accents, neutral gray hover highlights, charcoal surfaces, Inter typography, soft shadows and rounded windows. The active workspace pill is blue, and inactive workspace pills are white with contrasting labels. Noctalia panels, the bar, the dock and Alacritty use 96% opacity for slight glass transparency. Notifications and OSD popups use 97% opacity. Noctalia shell animations are disabled through `shell.animation.enabled=false` to remove button bounce and animated hover feedback. This shared switch also makes other Noctalia UI transitions immediate. The palette also includes a light variant. Set `desktop_theme_mode=light` when applying the desktop playbook to choose it. Noctalia's interactive mode control is under Settings → Appearance → Theme, or use `noctalia msg theme-mode-toggle` inside the desktop session.

The icon theme is [WhiteSur](https://github.com/vinceliuice/WhiteSur-icon-theme), pinned to commit `73d8040da51a9ed74e47c7366e7e9ff437601a5c`. Ansible installs it under `~/.local/share/icons` with the alternative macOS-style file-manager icons and bolder symbols for high-density displays. It selects `WhiteSur-dark` through GSettings for GTK applications and Noctalia's app launcher, with matching GTK 3/4 fallback settings. Light-mode playbook runs select `WhiteSur-light`. The source revision and selected theme are controlled by `desktop_whitesur_revision` and `desktop_icon_theme`. Installation tasks are in `roles/desktop/tasks/icons.yml`; they reinstall only when the pinned revision changes or an installed variant or completion marker is missing.

Noctalia 5.4.1 applies a fixed 55% alpha to empty workspace pills, so their configured white appears dimmed. Occupied inactive workspace pills use the full white color. [Workspace rendering](https://github.com/noctalia-dev/noctalia/blob/v5.4.1/src/shell/bar/widgets/workspaces_widget.cpp#L1495)

`desktop_glass` controls transparency separately from `desktop_blur`, which defaults to false. `desktop_surface_opacity` controls the shared 96% opacity. Noctalia draws floating panels solid, and a Niri layer rule applies their subtle transparency because Noctalia 5.4.1's built-in translucent panel presets are substantially more transparent. Attached panels inherit the bar's 96% opacity. The configuration disables compositor blur for windows and all layer surfaces, bar and dock blur requests, overview backdrop blur and lock-screen background blur. The curated files live under `roles/desktop/templates/`, and the palette is `roles/desktop/files/macos.json`. The palette uses the complete legacy format, including terminal colors, required by Noctalia 5.4.1's shell renderer. Current Noctalia also accepts that format. Existing GUI overrides for the managed theme, font, animation, transparency and blur settings are cleared when Ansible runs. [Noctalia palette formats](https://docs.noctalia.dev/noctalia/theming/palette/)

The VM output is 3840×2160 at 60 Hz with 2× scaling, giving a 1920×1080 logical workspace. `desktop_output_mode` and `desktop_output_scale` control those values when a specific output is selected. Native installs start with automatic monitor selection and scaling because `desktop_output` is empty. Set it to the laptop panel's connector name if you want to manage that panel explicitly.

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

The cloud image only bootstraps the account and SSH access. All desktop installation and configuration happens in Ansible. VM administration uses a generated SSH key and passwordless sudo inside the guest. Private keys, known hosts and the generated inventory stay in ignored `.local/` state. Guest disks and seed files live under `/var/lib/libvirt/images/fedora-niri/`.

VM-only settings enable automatic login, select the 4K virtual display, and install the QEMU guest agent. The virtual GPU uses VirtIO 3D and headless EGL through the host's Arc GPU at `/dev/dri/renderD128`. QEMU receives membership in the host's `render` group. Niri rejected the initial software-only virtual display. Native installations use their physical display and normal graphics defaults. Virtualization and graphics performance in this VM do not validate laptop Wi-Fi, suspend, fingerprint, battery or display scaling.

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

Super is Command when the VNC client forwards the Mac Command key as Super. Start a terminal with Super+T, open the launcher with Super+Space, toggle the overview with Super+Tab, and show the bindings with Super+Shift+/. Mac shortcuts may require configuring the viewer to pass them through.

For testing the Linux shortcuts from macOS, TigerVNC Viewer supports capturing system keys in full screen. Keep the SSH tunnel running and connect TigerVNC to `127.0.0.1::5901`. In its Input options, enable “Always send all keyboard input in full screen” and use full-screen mode. Allow TigerVNC under macOS System Settings → Privacy & Security → Accessibility when prompted. Current TigerVNC maps Command to Super and Option to Alt. Control+Option releases the keyboard capture, and Control+Option+M opens the viewer menu. This client setup requires verification on the Mac. [TigerVNC viewer options](https://tigervnc.org/doc/vncviewer.html), [Mac keyboard capture guidance](https://github.com/TigerVNC/tigervnc/issues/2024), [Mac modifier mapping](https://github.com/TigerVNC/tigervnc/blob/v1.16.2/vncviewer/KeyboardMacOS.mm)

QEMU VNC carries the VM console. Audio forwarding and a shared clipboard are not configured. Native wayvnc access is a separate experiment because Fedora's released Niri version may still have virtual input bugs.

Manage the VM on Ubuntu with libvirt.

```bash
sudo virsh shutdown fedora-niri
sudo virsh start fedora-niri
sudo virsh domifaddr fedora-niri
```

The VM does not automatically start when the Ubuntu host reboots. Run the VM playbook again if DHCP changes its address so that `.local/vm.yml` is refreshed.

## Verification

On November 4, 2026, the VM playbook completed on Ubuntu 26.04.1 with Fedora 45, Niri 26.04 and Noctalia 5.4.1. A repeat of the entire VM playbook reported zero changes on both host and guest. The repository was also cloned into Fedora, bootstrapped there, and applied locally with the native defaults. Its second local run reported zero changes.

The running desktop was verified at 3840×2160 at 60 Hz with 2× scaling, dark mode, 96% surface opacity and background blur disabled. A launcher screenshot confirmed faint transparency with sharp wallpaper and Settings content behind it. Noctalia and GTK both reported dark mode. Sending Super+T through VNC opened Alacritty. PipeWire and WirePlumber were active. WhiteSur-dark was selected in GSettings, its icon cache was present, and the launcher displayed the themed Firefox icon. The dark hover token was verified as neutral gray `#3A3A3C`. The appearance playbook's repeat run reported zero changes. Syntax checks and Ansible Lint passed. Physical Framework hardware still requires testing on that device.

The VM requires classic VNC password authentication for macOS Screen Sharing. Its challenge-response exchange accepted the configured password and returned a 3840×2160 console. Run the regression check against the running VM from the Ubuntu host with the default local password file.

```bash
.local/ansible/bin/python tests/check_vnc_auth.py
```

On first launch, Noctalia may show its welcome screen. Automatic login may also prompt to create or unlock a keyring. Those interactive choices can be made in the guest. Record any desktop settings chosen during experiments in the shared role before relying on them for the laptop installation.

## Sources

Fedora publishes Niri and Noctalia packages in its repositories. Noctalia's Niri integration documents the startup command and IPC bindings used here. [Niri package](https://packages.fedoraproject.org/pkgs/niri/niri/), [Noctalia package](https://packages.fedoraproject.org/pkgs/noctalia/noctalia/), [Noctalia integration](https://docs.noctalia.dev/noctalia/compositor-settings/niri/)

The Fedora 45 cloud image checksum was verified against Fedora's signed release manifest using Fedora's published signing keys. [Fedora cloud downloads](https://fedoraproject.org/cloud/download/), [Signing keys](https://fedoraproject.org/security/)
