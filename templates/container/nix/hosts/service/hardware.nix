# Incus system container profile.
#
# No kernel, bootloader, initrd, or disks are managed here: the container
# shares the host kernel and its rootfs lives on the host's Incus storage
# pool. This profile (lxc-container.nix) builds an Incus-importable image:
#
#   nix build .#nixosConfigurations.service.config.system.build.metadata
#   nix build .#nixosConfigurations.service.config.system.build.tarball
#   incus image import <metadata.tar.xz> <rootfs.tar.xz> --alias nixos-encrypted
{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/lxc-container.nix")
  ];

  system.stateVersion = "25.11";
}
