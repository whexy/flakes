{ flake, pkgs, ... }:
let
  nixos = flake.nixosConfigurations.service;
  inherit (nixos.config.system.build) image metadata;
in
pkgs.runCommand "nixos-gpu-container" { } ''
  mkdir -p $out
  ln -s ${image}/tarball/*.tar.xz $out/rootfs.tar.xz
  ln -s ${metadata}/tarball/*.tar.xz $out/metadata.tar.xz
''
