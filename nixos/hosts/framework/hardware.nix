# Hardware details nixos-generate-config would detect on the laptop. Review
# against `nixos-generate-config --show-hardware-config` during installation.
{ config, lib, ... }:
{
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "nvme"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;

  # Resume from the swap file. The offset is filled in at install time with
  # `btrfs inspect-internal map-swapfile -r /swap/swapfile`.
  boot.resumeDevice = "/dev/mapper/cryptroot";
}
