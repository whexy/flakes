{
  description = "Jupyter notebook setup";

  nixConfig = {
    extra-substituters = [ "https://cache.nixos-cuda.org" ];
    extra-trusted-public-keys = [ "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M=" ];
  };

  inputs = {
    # Tracks nixos-unstable-small at revisions the CUDA Hydra has built,
    # so torch with CUDA is available from cache.nixos-cuda.org.
    nixpkgs.url = "github:nixos-cuda/nixpkgs?ref=nixos-unstable-cuda";
    blueprint.url = "github:numtide/blueprint";
    blueprint.inputs.nixpkgs.follows = "nixpkgs";
    treefmt.url = "github:numtide/treefmt-nix";
    treefmt.inputs.nixpkgs.follows = "nixpkgs";
    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs:
    let
      # ── GPU mode ──────────────────────────────────────────────────────
      # Change this single line to switch GPU backend:
      #   "cuda"  – NVIDIA  (binary cache: cache.nixos-cuda.org)
      #   "rocm"  – AMD     (binary cache: cache.nixos.org)
      #   null    – CPU only
      gpu = null;
    in
    inputs.blueprint {
      inherit inputs;
      prefix = "nix";
      nixpkgs.config = {
        cudaSupport = gpu == "cuda";
        rocmSupport = gpu == "rocm";
        allowUnfree = gpu != null;
      };
    };
}
