{
  description = "Jupyter notebook setup";

  nixConfig = {
    extra-substituters = [ "https://cache.nixos-cuda.org" ];
    extra-trusted-public-keys = [ "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable-cuda";
    blueprint.url = "github:numtide/blueprint";
    blueprint.inputs.nixpkgs.follows = "nixpkgs";
    treefmt.url = "github:numtide/treefmt-nix";
    treefmt.inputs.nixpkgs.follows = "nixpkgs";
    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs:
    inputs.blueprint {
      inherit inputs;
      prefix = "nix";
      # Uncomment the following line to enable GPU acceleration (CUDA/ROCm):
      # nixpkgs.config.cudaSupport = true
      # nixpkgs.config.allowUnfree = true;
    };
}
