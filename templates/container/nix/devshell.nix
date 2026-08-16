{
  pkgs,
  ...
}:
pkgs.mkShell {
  packages = [
    pkgs.just
    # Add your language toolchain here, e.g.:
    #   pkgs.bun
    #   pkgs.go
    #   pkgs.rustc pkgs.cargo
    #   pkgs.python3
  ];
}
