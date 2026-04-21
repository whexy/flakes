{
  inputs,
  pkgs,
  perSystem,
  ...
}:
let
  pre-commit-check = import ./checks/pre-commit-check.nix { inherit inputs pkgs; };
  treefmtEval = inputs.treefmt.lib.evalModule pkgs ./treefmt.nix;
in
pkgs.mkShell {
  packages = [
    perSystem.self.typst
    perSystem.self.tinymist
    pkgs.zathura
    treefmtEval.config.build.wrapper
  ];

  shellHook = ''
    ${pre-commit-check.shellHook}

    echo "Dissertation dev shell ready."
    echo "  $(typst --version)"
    echo "  tinymist $(tinymist --version 2>/dev/null | head -1 || echo installed)"
    echo ""
    echo "  Compile:  typst compile src/main.typ main.pdf"
    echo "  Watch:    typst watch src/main.typ main.pdf"
    echo "  Preview:  zathura main.pdf &"
  '';
}
