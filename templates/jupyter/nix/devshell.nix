{ inputs, pkgs, ... }:
let
  pre-commit-check = import ./checks/pre-commit-check.nix { inherit inputs pkgs; };

  pythonPackages = ps: [
    ps.jupyterlab
    ps.jupyterlab-vim
    ps.numpy
    ps.matplotlib
    ps.torch
    ps.graphviz
  ];

  # --- CPU only (default) ---
  python = pkgs.python3.withPackages pythonPackages;

  # --- CUDA support (NVIDIA GPUs) ---
  # Uncomment this block and comment out the CPU-only line above.
  # Also uncomment `nixpkgs.config.allowUnfree` in flake.nix.
  # python =
  #   (pkgs.python3.override {
  #     self = python;
  #     packageOverrides = pyself: pysuper: {
  #       torch = pysuper.torch.override {
  #         cudaSupport = true;
  #       };
  #     };
  #   }).withPackages
  #     pythonPackages;

  # --- ROCm support (AMD GPUs) ---
  # Uncomment this block and comment out the CPU-only line above.
  # Also uncomment `nixpkgs.config.allowUnfree` in flake.nix.
  # python =
  #   (pkgs.python3.override {
  #     self = python;
  #     packageOverrides = pyself: pysuper: {
  #       torch = pysuper.torch.override {
  #         rocmSupport = true;
  #       };
  #     };
  #   }).withPackages
  #     pythonPackages;
in
pkgs.mkShell {
  packages = [
    python
    pkgs.graphviz
  ];

  env = { };

  shellHook = ''
    ${pre-commit-check.shellHook}
  '';
}
