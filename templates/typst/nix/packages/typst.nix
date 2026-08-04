{ pkgs, perSystem, ... }:
let
  # typst.withPackages transitively includes each package's typstDeps through
  # propagatedBuildInputs, so package dependencies are cached automatically.
  typstWithPackages = pkgs.typst.withPackages (p: [
    p.cetz # Drawing, diagrams, plots
    p.tablex # Extended table layout
    p.fletcher # Commutative diagrams and flowcharts
    p.touying # Presentation slides
  ]);
in
pkgs.symlinkJoin {
  name = "typst-${pkgs.typst.version}-env";
  paths = [ typstWithPackages ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/typst \
      --set TYPST_FONT_PATHS ${perSystem.self.fonts}
  '';
}
