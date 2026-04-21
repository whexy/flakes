# PDF output
# This package use typst to build the PDF.

{
  pkgs,
  flake,
  perSystem,
  ...
}:
pkgs.stdenvNoCC.mkDerivation {
  pname = "pdf";
  version = flake.shortRev or flake.dirtyShortRev or "unknown";

  src = pkgs.lib.cleanSource ../../.;

  nativeBuildInputs = [ perSystem.self.typst ];

  buildPhase = ''
    runHook preBuild
    typst compile src/main.typ main.pdf
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp main.pdf $out/
    runHook postInstall
  '';
}
