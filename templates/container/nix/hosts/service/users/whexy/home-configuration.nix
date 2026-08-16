{ perSystem, ... }:
{
  home.stateVersion = "25.11";

  services.myservice = {
    enable = true;
    package = perSystem.self.default;
    port = 8080;
    # settings = {
    #   # Freeform TOML merged into myservice.toml
    # };
  };
}
