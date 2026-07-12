# NixOS GPU Service

This repo contains a nix flake of NixOS config, which is designed to run as a
system container image. Multiple images can be generated towards different
backends, such as `incus` or Proxmox LXC.

This repo is a template for future GPU service serving.

## Features

- An example service declared as both NixOS module and Home Manager module,
  which runs a GPU task. In this example, it is `nvidia-smi`.
- A NixOS system-container image for Incus with the existing user, SSH,
  NetworkManager, Tailscale, and Home Manager configuration.

## NVIDIA Driver

The container uses Incus's `nvidia.runtime` support. Incus passes the NVIDIA
and CUDA userspace components from the host into the container, keeping NVML
and the host kernel driver synchronized. NixOS enables `nix-ld` so injected
FHS binaries can use their expected ELF interpreter.

The image does not install an NVIDIA driver or CUDA runtime.

## Build And Import

Build the image and metadata together through the default package:

```sh
nix build
```

Import the split image into Incus:

```sh
incus image import \
  result/metadata.tar.xz \
  result/rootfs.tar.xz \
  --alias nixos-gpu-service
```

Create the unprivileged container with NVIDIA runtime injection enabled, attach
the standard Incus GPU device, and start it:

```sh
incus init nixos-gpu-service nixos-gpu-service \
  -s default \
  -c nvidia.runtime=true
incus config device add nixos-gpu-service gpu gpu
incus start nixos-gpu-service
```

No privileged-container mode, raw LXC configuration, or manually maintained
library mount is required. Verify GPU access manually:

```sh
incus exec nixos-gpu-service -- nvidia-smi
```

## Future Plans

- Extend from Nvidia GPU to multiple GPU brand supports.
