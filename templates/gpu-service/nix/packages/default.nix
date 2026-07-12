{ flake, pkgs, ... }:
let
  nixos = flake.nixosConfigurations.service;
  image = nixos.config.system.build.image;
  metadata = nixos.config.system.build.metadata;
in
pkgs.runCommand "nixos-gpu-container" { } ''
  mkdir -p $out
  ln -s ${image}/tarball/*.tar.xz $out/rootfs.tar.xz
  ln -s ${metadata}/tarball/*.tar.xz $out/metadata.tar.xz
''
