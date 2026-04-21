# Tinymist is a third party LSP for Typst.
#
# It runs with bundled typst compiler, so our wrap to add fonts and packages to
# the typst compiler doesn't work here.
#
# This package re-export the tinymist package with the necessary environment
# set to the correct path.

{ pkgs, perSystem, ... }:
pkgs.symlinkJoin {
  name = "tinymist-${pkgs.tinymist.version}";
  paths = [ pkgs.tinymist ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/tinymist \
      --set TYPST_FONT_PATHS ${perSystem.self.fonts} \
      --set TYPST_PACKAGE_CACHE_PATH ${perSystem.self.typst}/lib/typst/packages
  '';
}
