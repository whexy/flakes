{ pkgs, ... }:
{
  projectRootFile = "flake.nix";
  programs = {
    nixfmt.enable = true;
    typstyle.enable = true;
    typstyle.wrapText = true;
    stylua.enable = true;
  };
  settings.formatter.bibtex-tidy = {
    # bibtex-tidy requires input files before its flags, while treefmt appends
    # files after options. Avoid rewriting unchanged files as well.
    command = "${pkgs.writeShellScript "bibtex-tidy-fmt" ''
      set -e
      for f in "$@"; do
        tmp="$(mktemp)"
        ${pkgs.lib.getExe pkgs.bibtex-tidy} "$f" -o "$tmp"
        if ! cmp -s "$tmp" "$f"; then
          cp "$tmp" "$f"
        fi
        rm -f "$tmp"
      done
    ''}";
    includes = [ "*.bib" ];
  };
}
