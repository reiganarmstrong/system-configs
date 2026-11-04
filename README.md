# Fedora desktop

Ansible configures Fedora with Niri and Noctalia. The Fedora VM is the rehearsal for installing the same desktop on a Framework 13 Pro after the Fedora installer finishes.

The `desktop` role owns the desktop packages, Niri configuration, Noctalia startup, key bindings, desktop portals, audio packages and default login session. Both the VM and native laptop execute that role. Changes made while experimenting belong in the role and are reapplied with Ansible.

## Native Fedora installation

Install Fedora 45 Workstation or newer and create your normal user account with administrator privileges. Log in as that user and install the bootstrap tools.

```bash
sudo dnf install -y git python3-pip
git clone reagan@192.168.1.215:/home/reagan/documents/github/fedora-desktop
cd fedora-desktop
./bootstrap.sh
.local/ansible/bin/ansible-playbook desktop.yml --ask-become-pass
```

The clone command reads this Git repository over SSH from the Ubuntu server. Substitute a Git hosting URL if it is published later. Run Ansible as your normal user. It configures that account by default. Use `-e desktop_user=NAME` to select another existing account.

The bootstrap script installs Ansible Core 2.22.0 and the collection versions in `requirements.yml` into ignored `.local/` directories. Ansible 2.22 supports Fedora 45's Python 3.15. Older controller versions fail before running desktop tasks.

Reboot after the first run, then select Niri from the login screen's session menu if needed. Automatic login is disabled for native installations. Subsequent runs use the same command. Configuration changes to Niri normally reload while the session is running.

Fedora 45 is the tested starting release. Packages track Fedora's repositories, so later runs can install newer dependency versions. This repository reproduces the configuration and package selection rather than an immutable OS image.

## Rehearsal VM on Ubuntu

Install Git and Python's venv support on the Ubuntu host with `sudo apt install git python3-venv`. Clone this repository and run `./bootstrap.sh`. Then run the VM playbook as your normal host user.

```bash
.local/ansible/bin/ansible-playbook vm.yml --ask-become-pass
```

The VM playbook installs QEMU/libvirt, downloads the checksum-pinned Fedora 45 cloud image, creates a 60 GiB expandable disk, assigns four virtual CPUs and 8 GiB RAM, and starts the guest on libvirt's default NAT network. It then runs the same `desktop` role used by `desktop.yml` on a native laptop.

The cloud image only bootstraps the account and SSH access. All desktop installation and configuration happens in Ansible. VM administration uses a generated SSH key and passwordless sudo inside the guest. Private keys, known hosts and the generated inventory stay in ignored `.local/` state. Guest disks and seed files live under `/var/lib/libvirt/images/fedora-niri/`.

VM-only settings enable automatic login, select a 1280×800 virtual display, disable Noctalia blur, and install the QEMU guest agent. The virtual GPU uses VirtIO 3D and headless EGL through the host's Arc GPU at `/dev/dri/renderD128`. QEMU receives membership in the host's `render` group. Niri rejected the initial software-only virtual display. Native installations use their physical display and normal graphics defaults. Virtualization and graphics performance in this VM do not validate laptop Wi-Fi, suspend, fingerprint, battery or display scaling.

To apply a desktop change to the VM, run this from the Ubuntu host.

```bash
.local/ansible/bin/ansible-playbook -i .local/vm.yml desktop.yml
```

Run the same command again to check that it reports no unintended changes. To check the native configuration without applying changes, add `--check --diff` to the native command on an already configured Fedora installation.

`vars/vm.yml` contains the VM resources and image checksum. Changes to virtual hardware trigger a graceful VM shutdown and definition update on the next VM playbook run. Shut down the guest before increasing its disk size. Cloud-init account changes require a fresh VM. The playbook preserves existing guest disks and does not rebuild them on another run. A new host must have `/dev/kvm`, hardware virtualization enabled and a GPU render device suitable for headless EGL.

## Connect from the Mac

Forward the VM console through SSH to the Ubuntu host.

```bash
ssh -N -L 5901:127.0.0.1:5901 reagan@192.168.1.215
```

Keep that terminal running. Connect a VNC viewer to `127.0.0.1` on port `5901`. The built-in macOS Screen Sharing application can be opened with `open vnc://127.0.0.1:5901`. The console listens only on the Ubuntu host's loopback address and uses SSH for access. Substitute your host address when using another machine or Tailscale.

Super is Command when the VNC client forwards the Mac Command key as Super. Start a terminal with Super+T, open the launcher with Super+Space, toggle the overview with Super+Tab, and show the bindings with Super+Shift+/. Mac shortcuts may require configuring the viewer to pass them through.

QEMU VNC carries the VM console. Audio forwarding and a shared clipboard are not configured. Native wayvnc access is a separate experiment because Fedora's released Niri version may still have virtual input bugs.

Manage the VM on Ubuntu with libvirt.

```bash
sudo virsh shutdown fedora-niri
sudo virsh start fedora-niri
sudo virsh domifaddr fedora-niri
```

The VM does not automatically start when the Ubuntu host reboots. Run the VM playbook again if DHCP changes its address so that `.local/vm.yml` is refreshed.

## Sources

Fedora publishes Niri and Noctalia packages in its repositories. Noctalia's Niri integration documents the startup command and IPC bindings used here. [Niri package](https://packages.fedoraproject.org/pkgs/niri/niri/), [Noctalia package](https://packages.fedoraproject.org/pkgs/noctalia/noctalia/), [Noctalia integration](https://docs.noctalia.dev/noctalia/compositor-settings/niri/)

The Fedora 45 cloud image checksum was verified against Fedora's signed release manifest using Fedora's published signing keys. [Fedora cloud downloads](https://fedoraproject.org/cloud/download/), [Signing keys](https://fedoraproject.org/security/)
