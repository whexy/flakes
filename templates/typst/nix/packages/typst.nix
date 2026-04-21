{ pkgs, perSystem, ... }:
let
  typstWithPackages = pkgs.typst.withPackages (p: [
    p.cetz # Drawing, diagrams, plots            (cetz:0.4.2)
    p.tablex # Extended table layout                (tablex:0.0.9)
    p.fletcher # Commutative diagrams / flowcharts    (fletcher:0.5.8)
    # Transitive dependencies that withPackages does not cache automatically:
    p.cetz_0_3_4 # fletcher:0.5.8 internally imports @preview/cetz:0.3.4
    p.oxifmt_0_2_1 # cetz:0.3.4 depends on @preview/oxifmt:0.2.1
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
