{ inputs, pkgs, ... }:
let
  pre-commit-check = import ./checks/pre-commit-check.nix { inherit inputs pkgs; };

  pythonPackages = ps: [
    ps.torch
  ];

  python = pkgs.python3.withPackages pythonPackages;

  runtimeLibs = pkgs.lib.makeLibraryPath [
    pkgs.stdenv.cc.cc.lib # libstdc++
    pkgs.zlib
  ];

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
    pkgs.uv
  ];

  env.LD_LIBRARY_PATH = runtimeLibs;

  shellHook = ''
    ${if pkgs.config.cudaSupport then cudaDriverHook else ""}
    ${pre-commit-check.shellHook}

    export UV_PYTHON_DOWNLOADS=never
    if [ ! -d .venv ]; then
      uv venv --python "$(which python)" --system-site-packages
    fi
    source .venv/bin/activate
    uv pip install --quiet -r requirements.txt

    export JUPYTER_CONFIG_PATH="${./jupyter}"
    export JUPYTER_PYLSP_PYTHON="$(which python)"
  '';
}
