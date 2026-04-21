_: {
  projectRootFile = "flake.nix";

  programs = {
    nixfmt.enable = true;
    typstyle.enable = true;
    typstyle.wrapText = true;
    stylua.enable = true;
  };

}
