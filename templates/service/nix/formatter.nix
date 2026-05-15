{
  pkgs,
  inputs,
  ...
}:
let
  treefmtEval = inputs.treefmt-nix.lib.evalModule pkgs {
    projectRootFile = "flake.nix";
    programs = {
      nixfmt.enable = true;
      prettier.enable = true;
      shfmt.enable = true;
      taplo.enable = true;
    };
  };
in
treefmtEval.config.build.wrapper
