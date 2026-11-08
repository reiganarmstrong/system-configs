# Framework 13 Pro hardware setup

The Niri playbook installs Fedora's maintained kernel, firmware, fingerprint and camera packages. It uses stock drivers and adds no third-party kernel, vendor driver script or model-specific boot flags. Hardware packages live in `roles/niri/defaults/main.yml`; authentication setup lives in `roles/niri/tasks/hardware.yml`.

The target is the Intel Framework 13 Pro with the user-supplied 32 GB RAM and 1 TB SSD. The wallpaper's generic Intel Core i5 label does not identify a precise CPU SKU. Framework's current [Intel 13 Pro Linux matrix](https://frame.work/laptop13pro?tab=linux) lists a minimum kernel of 6.19 and recommends 7.0 or newer. Start from Fedora 45 Workstation or newer, follow the [matching official completion guide](https://github.com/FrameworkComputer/linux-docs/blob/main/framework13/FW-13-Pro-Fedora-all-Intel-Core-Ultra-Series-3.md), and update before relying on the hardware:

```bash
sudo dnf upgrade --refresh
```

Reboot to use an updated kernel and microcode. Ansible never reboots the machine automatically. Installing packages is preparation, not evidence that the physical reader, camera, radio or dock has been tested.

## Drivers and firmware

The role explicitly installs `kernel`, `linux-firmware`, `iwlwifi-mvm-firmware`, `iwlbluetooth-firmware`, `intel-gpu-firmware`, `intel-audio-firmware`, `alsa-sof-firmware`, `alsa-ucm`, `microcode_ctl` and `pipewire-plugin-libcamera`. This matters because the profile disables weak RPM dependencies. The kernel package supplies its matching common modules; the camera backend brings libcamera. NetworkManager, BlueZ, PipeWire/WirePlumber, power profiles, portals, CUPS and Avahi are already configured by the profile.

These cover the stock Intel graphics, Wi-Fi, Bluetooth, audio, camera and general USB/input stack. External devices can have their own firmware or vendor limitations. Niri keeps normal libinput support and automatic output selection, with no laptop-specific connector name copied from the VM.

`fwupd` provides LVFS firmware tooling. Check the [current release notes for the exact laptop model](https://resources.frame.work/downloads/laptop-13-pro/intel-core-ultra-3/) before applying an update. On the laptop:

```bash
fwupdmgr get-devices
fwupdmgr refresh --force
fwupdmgr get-updates
```

Review the device identity, release notes and power requirements before running `fwupdmgr update`. Ansible never downloads a hardcoded BIOS image or flashes firmware.

## Fingerprint and password login

The role installs Fedora's `fprintd`, `fprintd-pam` and `authselect`. It validates the existing authentication policy, verifies that the selected profile supports `with-fingerprint`, and enables that feature with a native backup. It preserves the selected profile, its other features and password fallback. It refuses to overwrite an invalid or unsupported policy. Set `-e niri_fingerprint_pam_enabled=false` to leave PAM policy unchanged; this does not disable an existing fingerprint feature.

The PAM feature also applies to other consumers of the profile, such as sudo. The daemon starts through D-Bus when needed; it is not a service to enable at every boot. Noctalia 5.4.1 has [native fprintd lock-screen support](https://github.com/noctalia-dev/noctalia/blob/v5.4.1/src/auth/fingerprint_authenticator.cpp), enabled by default. No extra lock-screen plugin or custom PAM file is installed.

Enroll and verify your own finger on the physical laptop as your normal account:

```bash
fprintd-enroll
fprintd-verify
fprintd-list "$USER"
```

Use your password for the initial GDM login when you want oo7 to unlock the login keyring automatically. A fingerprint-only fresh login supplies no password to decrypt that keyring, so a later keyring password prompt is expected. Fingerprint unlock after the session is running avoids that initial-login limitation. Password authentication remains available.

## Tailscale

Tailscale is enabled by default in the role. Ansible checks the official Fedora repository key, verifies package and metadata signatures, installs the client, enables and starts `tailscaled`, and sets the desktop account as its operator. Reapplying the role preserves existing enrollment and routing/DNS preferences.

The new machine still needs your one-time browser authentication:

```bash
sudo tailscale up
# After completing the browser sign-in:
sudo tailscale set --operator="$USER"
tailscale status
tailscale ip -4
```

The [official Linux instructions](https://tailscale.com/docs/install/linux) describe that sign-in. The [`tailscale set --operator` command](https://tailscale.com/docs/reference/troubleshooting/linux/linux-operator-permission) sets permission on the authenticated profile. Before a machine has its first saved login profile, an operator preference can be temporary and disappear when the daemon restarts, so repeat the operator command after completing the browser sign-in. Then test reaching a known peer. No auth key or account credential belongs in this repository. The role does not configure a subnet router, exit node or forced route/DNS preferences. Set `-e niri_tailscale_enabled=false` to skip setup; this leaves an already installed connection alone.

## Physical checks after installation

The VM verifies provisioning and configuration, including authselect profile preservation and the unauthenticated Tailscale service/operator setup. It cannot verify the laptop's devices. Check the following on both AC and battery where relevant:

- Password login, fingerprint enrollment, Noctalia lock/unlock and keyring access.
- Wi-Fi reconnect after resume, Bluetooth pairing and battery/brightness controls.
- Speakers, microphone, headphones, webcam and physical privacy switches.
- Haptic touchpad, keyboard controls, display scale and refresh rate.
- Each expansion card, USB-C/Thunderbolt dock, external monitor, Ethernet and charging path.
- Lid suspend/resume, power profiles and idle behavior.

Use the model's current Framework guidance if a device fails. Driver installation alone does not guarantee that an arbitrary peripheral is supported.
