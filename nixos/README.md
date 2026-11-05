# NixOS desktop

NixOS 26.05 with Hyprland and a hand-written [Quickshell](https://quickshell.org) desktop shell, for a Framework Laptop 13 Pro (Intel Core Ultra 5 325). The look is monochrome frosted glass over a colourful wallpaper. It is modelled on the screenshots of [0xby7eMe/dotfiles](https://github.com/0xby7eMe/dotfiles). That repository has no licence, so nothing here is copied from it: every config, QML file and the wallpaper are written for this repository.

## Layout

| Path | What it holds |
| --- | --- |
| `flake.nix` (repo root) | Inputs (stable nixpkgs and Home Manager, nixos-hardware, Disko) and the two hosts. |
| `hosts/framework/` | The laptop: hardware profile, display, Disko disk layout. |
| `hosts/vm/` | The test VM. |
| `modules/nixos/` | System modules. Hosts only set `desktop.*` options. |
| `modules/nixos/theme.nix` | **The single source for the look**: colours, opacities, radii, spacing, blur, shadows, fonts, wallpaper. |
| `modules/home/hyprland/` | Hyprland's Lua config. Nix generates `nix.lua` with the theme and display values. |
| `modules/home/quickshell/` | The shell's QML. Nix adds `theme.json` and `icons.json` (Lucide names to glyphs). |
| `modules/home/apps/` | Ghostty, zsh with oh-my-zsh and Starship, development tools, T3 Code and Claude Code. |
| `assets/wallpaper.svg` | The wallpaper, rendered to PNG at build time. |

### Options hosts set

| Option | Default | Meaning |
| --- | --- | --- |
| `desktop.enable` | `false` | The Hyprland desktop. |
| `desktop.display.{output,mode,scale}` | any, `preferred`, `1` | The built-in display. |
| `desktop.autoLogin` | `true` | Start Hyprland at boot and lock it immediately; the lock screen is the login screen. |
| `desktop.updates.enable` | `false` | Daily automatic upgrades from GitHub. |
| `desktop.dock.pinned` | Ghostty, Zen, T3 Code | Desktop entry IDs always in the dock. |
| `desktop.flatpaks` | Zen | Flathub apps, installed system-wide and updated daily. |
| `desktop.theme.*` | see `theme.nix` | The look. |

## The shell

| Part | How to open it |
| --- | --- |
| Bar: workspace dots, clock, status | Always at the top. |
| Control centre: session buttons, Wi-Fi, Bluetooth, Airplane Mode, Do Not Disturb, Night Light, Caffeine, brightness, volume, now playing, power profile, microphone, screenshot, colour picker | Click the status pill, or `Super+S`. |
| Notification centre: calendar and history | Click the clock. |
| Launcher | `Super+Space`. |
| Dock | Touch the bottom edge of the screen. |
| Lock screen | At boot, `Super+L`, or the lock button. |
| Volume and brightness pop-ups | The hardware keys. |

Other bindings: `Super+T` terminal, `Super+Q` close, `Super+F` fullscreen, `Super+V` float, `Super+arrows` focus (with `Shift` to move), `Super+1`–`0` workspaces (with `Shift` to move the window). The full scheme comes later.

Unlocking the lock screen also unlocks GNOME Keyring, which autologin can't do. Without it, apps that store secrets ask for the keyring password.

## Apps

- **Ghostty** from nixpkgs, translucent so Hyprland blurs behind it.
- **Zen** from Flathub, as on Fedora. Flatpak updates it daily.
- **Claude Code** through Anthropic's native installer (the latest channel, as on Fedora). A user service installs it once into `~/.local/bin`, and it updates itself from then on. Stable nixpkgs lags it by months.
- **T3 Code**: Nix places the pinned first-install AppImage in `~/Applications` once, and the app updates itself in place.
- **zsh** with oh-my-zsh, autosuggestions, syntax highlighting, the Starship prompt and the aliases and functions from the Fedora setup. Put machine-only additions in `~/.zshrc.local`.
- Node 24, pnpm, uv, git, vim and make.

`programs.nix-ld` and AppImage support let these prebuilt vendor binaries run on NixOS.

## Updates

1. Every Monday, the **NixOS update** workflow runs `nix flake update` on the pinned stable release, builds both hosts, and commits `flake.lock` only if they build.
2. The laptop runs `system.autoUpgrade` daily from `github:reiganarmstrong/system-configs`. It builds in the background and applies at the next boot. It never reboots on its own.
3. Each build stays in the boot menu for 14 days; pick an older one to roll back.
4. On the 20th of each month, the **NixOS release upgrade** workflow checks for the next NixOS release. When one exists, it opens a pull request moving to it, which is the one manual step, twice a year. Test the pull request in the VM before merging.

The **NixOS check** workflow builds both hosts on every change under `nixos/` or to the flake.

## Testing in a VM

`nixos-rebuild build-vm` builds a throwaway QEMU VM straight from the flake. The VM renders through the host GPU (virtio-gpu with virgl), which Hyprland needs, and is viewed over VNC on `127.0.0.1:5902`. The VNC password is read at start-up from the file `$VNC_PASSWORD_FILE` names; VNC uses its first eight characters.

On a non-NixOS host, Nix's QEMU looks for GPU drivers in `/run/opengl-driver`, which only NixOS has, so point it at Nix's Mesa. The host user must be in the `kvm` and `render` groups.

```bash
nix build .#nixosConfigurations.vm.config.system.build.vm
mesa=$(nix build --no-link --print-out-paths "$(nix eval --raw .#nixosConfigurations.vm.pkgs.mesa.drvPath)^out")
GBM_BACKENDS_PATH=$mesa/lib/gbm \
LIBGL_DRIVERS_PATH=$mesa/lib/dri \
__EGL_VENDOR_LIBRARY_FILENAMES=$mesa/share/glvnd/egl_vendor.d/50_mesa.json \
VNC_PASSWORD_FILE=fedora/.local/vnc-password \
  ./result/bin/run-vm-vm
```

The VM's password is `nixos`, and SSH from the host works on `127.0.0.1:2222` with the host user's `~/.ssh/id_ed25519.pub`. Its disk, `vm.qcow2`, is created in the current directory; delete it for a fresh first boot.

To view it from another machine on the tailnet, tunnel the port over SSH, then open `vnc://localhost:5902` (on a Mac, in Finder's **Go → Connect to Server**):

```bash
ssh -N -L 5902:127.0.0.1:5902 reagan@pc.taila028da.ts.net
```

## Installing on the Framework

1. Boot the NixOS 26.05 (or newer) minimal ISO and connect to the network.
2. Check the disk name with `lsblk`, and edit `hosts/framework/disko.nix` if it isn't `/dev/nvme0n1`.
3. Partition, encrypt and mount. This erases the disk and asks for the disk encryption password:

   ```bash
   sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- \
     --mode destroy,format,mount --flake github:reiganarmstrong/system-configs#framework
   ```

4. Compare `nixos-generate-config --show-hardware-config --no-filesystems --root /mnt` with `hosts/framework/hardware.nix`, and commit any differences.
5. Install, set your password, and reboot:

   ```bash
   sudo nixos-install --flake github:reiganarmstrong/system-configs#framework --no-root-passwd
   sudo nixos-enter --root /mnt -c 'passwd reagan'
   sudo reboot
   ```

6. For hibernation, find the swap file's offset with `sudo btrfs inspect-internal map-swapfile -r /swap/swapfile`, add `boot.kernelParams = [ "resume_offset=<offset>" ];` to `hosts/framework/hardware.nix`, and push.

After the first boot, the disk password unlocks the machine, Hyprland starts locked, and your account password unlocks it.
