{ pkgs, ... }:
{
  home.stateVersion = "25.11";

  services.myservice = {
    enable = true;
    package = pkgs.writeShellScriptBin "myservice" ''
      exec /usr/bin/nvidia-smi "$@"
    '';
    extraArgs = [ ];
    port = 8080;
    # settings = {
    #   # Freeform TOML merged into myservice.toml
    # };
  };
}
