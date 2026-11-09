# Test VM built with `nixos-rebuild build-vm --flake .#vm`. It renders through
# the host GPU (virtio-gpu with virgl) and is viewed over VNC on 127.0.0.1:5902.
# The VNC password is read from the file named by $VNC_PASSWORD_FILE when the
# VM starts; classic VNC authentication uses its first eight characters.
{ lib, ... }:
{
  imports = [ ./test-hardware.nix ];

  networking.hostName = "vm";

  # The Framework's layout (2880x1920 at 2x) at 1x, so VNC viewers that
  # aren't HiDPI-aware, like TigerVNC on a Mac, show it at a sensible size.
  desktop = {
    enable = true;
    # A suspended QEMU guest cannot be woken reliably through its VNC keyboard.
    autoSuspend = false;
    # S3 resumes the guest but leaves the virtio/VNC display inactive;
    # s2idle also cannot be woken reliably through virtual keyboard input.
    suspendSupported = false;
    display.scale = 1;
    # Virgl rejects restoring the initial mode after a live resolution change.
    display.fixedMode = true;
  };

  # Throwaway test machine: a fixed password, so the lock screen can be tested.
  users.users.reagan.initialPassword = "nixos";
  users.mutableUsers = false;

  # SSH from the host on 127.0.0.1:2222, for logs and `Hyprland msg` while testing.
  services.openssh.enable = true;
  users.users.reagan.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMULy3x+bptXlXcZ6JmEh5dKxrHyqaY8uoplaEGGWKQy pc"
  ];

  virtualisation.vmVariant.virtualisation = {
    memorySize = 8192;
    cores = 4;
    # Boot from a disk image of the system's store, not the host's /nix/store
    # over 9p. GTK apps stat thousands of icon files as they start, and each
    # one is a round trip to the host over 9p: Ghostty took 11 s to open.
    useNixStoreImage = true;
    # A writable layer over the image, cleared on each boot. Home Manager's
    # activation registers its generation in the store and fails without it.
    writableStore = true;
    diskSize = 20480;
    resolution = {
      x = 1440;
      y = 960;
    };
    forwardPorts = [
      {
        from = "host";
        host.address = "127.0.0.1";
        host.port = 2222;
        guest.port = 22;
      }
    ];
    qemu.options = [
      "-device virtio-vga-gl,xres=1440,yres=960"
      "-display egl-headless,rendernode=/dev/dri/renderD128"
      "-object secret,id=vncpass,file=$VNC_PASSWORD_FILE"
      # Every viewer is let in and none can kick the others off, so a test
      # client can connect while you're viewing. (force-shared would instead
      # refuse viewers that ask for exclusive access, like TigerVNC by default.)
      "-vnc 127.0.0.1:2,password-secret=vncpass,share=ignore"
      # A silent sound card with an output and an input, for testing volume
      # and the microphone toggle.
      "-audiodev none,id=snd0"
      "-device intel-hda"
      "-device hda-duplex,audiodev=snd0"
    ];
  };

  # build-vm boots its own kernel and disk; there is no bootloader to install.
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.grub.enable = false;
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
}
