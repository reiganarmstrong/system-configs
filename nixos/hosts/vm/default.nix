# Test VM built with `nixos-rebuild build-vm --flake .#vm`. It renders through
# the host GPU (virtio-gpu with virgl) and is viewed over VNC on 127.0.0.1:5902.
{ lib, ... }:
{
  networking.hostName = "vm";

  desktop = {
    enable = true;
    display.scale = 2;
  };

  # Throwaway test machine: a fixed password, so the lock screen can be tested.
  users.users.reagan.initialPassword = "nixos";
  users.mutableUsers = false;

  # SSH from the host on 127.0.0.1:2222, for logs and hyprctl while testing.
  services.openssh.enable = true;
  users.users.reagan.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMULy3x+bptXlXcZ6JmEh5dKxrHyqaY8uoplaEGGWKQy pc"
  ];

  virtualisation.vmVariant.virtualisation = {
    memorySize = 8192;
    cores = 4;
    diskSize = 20480;
    resolution = {
      x = 3840;
      y = 2160;
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
      "-device virtio-vga-gl,xres=3840,yres=2160"
      "-display egl-headless,rendernode=/dev/dri/renderD128"
      "-vnc 127.0.0.1:2"
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
