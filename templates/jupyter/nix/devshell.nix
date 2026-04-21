{ inputs, pkgs, ... }:
let
  pre-commit-check = import ./checks/pre-commit-check.nix { inherit inputs pkgs; };
  python = pkgs.python3.withPackages (ps: [
    ps.jupyterlab
    ps.jupyterlab-vim
    ps.numpy
    ps.matplotlib
    ps.torch
    ps.graphviz
  ]);
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
