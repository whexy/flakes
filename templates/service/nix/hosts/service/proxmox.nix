# Proxmox-specific overrides for image generation
# Imported only during `just build-proxmox`, not during normal nixos-rebuild
{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/proxmox-image.nix")
  ];

  proxmox.qemuConf.bios = "ovmf";
}
