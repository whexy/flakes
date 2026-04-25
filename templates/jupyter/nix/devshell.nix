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
    ps.tqdm
  ];

  # When cudaSupport / rocmSupport is enabled in flake.nix the nixpkgs instance
  # already builds torch against the selected GPU backend.  For CUDA this matches
  # the builds on cache.nixos-cuda.org, so torch is fetched from the binary cache
  # instead of being compiled from source.
  python = pkgs.python3.withPackages pythonPackages;

  # ── NVIDIA driver shim (non-NixOS only) ────────────────────────────
  # On NixOS, libcuda.so.1 is already available via /run/opengl-driver/lib
  # (baked into the torch RPATH by addDriverRunpath).  On non-NixOS the host
  # NVIDIA driver libraries live alongside the system libc, so we can't just
  # add that directory to LD_LIBRARY_PATH without glibc symbol conflicts.
  # Instead, create a temporary directory that symlinks only the NVIDIA driver
  # libraries we need.
  cudaDriverHook = ''
    if [ ! -e "${pkgs.addDriverRunpath.driverLink}/lib/libcuda.so.1" ]; then
      __cuda_driver_dir="$(mktemp -d /tmp/nix-cuda-driver.XXXXXX)"
      for __dir in /usr/lib/x86_64-linux-gnu /usr/lib64 /usr/lib/wsl/lib; do
        if [ -e "$__dir/libcuda.so.1" ]; then
          ln -sf "$__dir"/libcuda.so* "$__cuda_driver_dir/"
          ln -sf "$__dir"/libnvidia*.so* "$__cuda_driver_dir/" 2>/dev/null
          break
        fi
      done
      export LD_LIBRARY_PATH="$__cuda_driver_dir''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      unset __dir
    fi
  '';
in
pkgs.mkShell {
  packages = [
    python
    pkgs.graphviz
  ];

  env = { };

  shellHook = ''
    ${if pkgs.config.cudaSupport then cudaDriverHook else ""}
    ${pre-commit-check.shellHook}
  '';
}
