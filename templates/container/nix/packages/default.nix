{ pkgs, ... }:
# Replace this stub with the real build of your service.
#
# Examples:
#
#   # Bun (via bun2nix):
#   let bun2nix = inputs.bun2nix.packages.${system}.default;
#   in bun2nix.mkDerivation {
#     pname = "myservice";
#     version = "0.1.0";
#     src = ../../.;
#     bunDeps = bun2nix.fetchBunDeps { bunNix = ../../bun.nix; };
#     module = "src/index.ts";
#   }
#
#   # Rust:
#   pkgs.rustPlatform.buildRustPackage {
#     pname = "myservice";
#     version = "0.1.0";
#     src = ../../.;
#     cargoLock.lockFile = ../../Cargo.lock;
#   }
#
#   # Go:
#   pkgs.buildGoModule {
#     pname = "myservice";
#     version = "0.1.0";
#     src = ../../.;
#     vendorHash = null;
#   }
#
#   # Python:
#   pkgs.python3Packages.buildPythonApplication {
#     pname = "myservice";
#     version = "0.1.0";
#     src = ../../.;
#   }
#
# The stub below produces a runnable `myservice` binary that accepts
# `serve --config <path>` so the bundled systemd service module works
# out of the box.
pkgs.writeShellApplication {
  name = "myservice";
  text = ''
    cmd="''${1:-}"
    case "$cmd" in
      serve)
        shift
        echo "myservice: starting (args: $*)"
        # Replace this with your real server entrypoint.
        # Sleep so systemd sees the unit as running.
        exec sleep infinity
        ;;
      *)
        echo "Usage: myservice serve --config <path>"
        exit 1
        ;;
    esac
  '';
}
