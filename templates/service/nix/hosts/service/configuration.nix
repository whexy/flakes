{
  flake,
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware.nix
    inputs.agenix.nixosModules.default
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  nix.settings.require-sigs = false;

  users.users.whexy = {
    isNormalUser = true;
    home = "/home/whexy";
    # TODO: replace with your own password hash, generated via:
    #   mkpasswd -m yescrypt
    hashedPassword = "$y$j9T$hS1I2iWez3k8r1EH6ZIKG.$rATY9sBbSiudRf7T5MOEWlLraL6WFY5K6uB0MZj3Q.4";
    shell = pkgs.zsh;
    extraGroups = [ "wheel" ];
    linger = true;
    # TODO: replace with your own SSH public key(s).
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMdMvHl7VPzajwBjWw+pqcLatA42yWtQKiEPj/9VqI9i"
    ];
  };

  programs.zsh.enable = true;
  programs.vim.enable = true;

  networking.networkmanager.enable = true;
  networking.hostName = "service";

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  services.tailscale.enable = true;

  home-manager.sharedModules = [
    inputs.agenix.homeManagerModules.default
    flake.modules.home.myservice
  ];

  security.sudo.wheelNeedsPassword = false;
}
