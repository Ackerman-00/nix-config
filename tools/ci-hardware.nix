{
  config,
  lib,
  modulesPath,
  ...
}:
{
  imports = [ "${modulesPath}/profiles/qemu-guest.nix" ];

  fileSystems."/" = {
    device = "/dev/vda1";
    fsType = "ext4";
  };

  boot.loader = {
    systemd-boot.enable = lib.mkForce false;
    grub.enable = lib.mkForce false;
    efi.canTouchEfiVariables = lib.mkForce false;
  };
}
