{
  flake,
  inputs,
  modulesPath,
  pkgs,
  ...
}:
{
  imports = [
    (modulesPath + "/virtualisation/lxc-container.nix")
    inputs.agenix.nixosModules.default
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  nix.settings.require-sigs = false;

  # Incus unprivileged containers cannot give the Nix daemon sufficient
  # mount privileges to remount a read-only /nix/store writable in its
  # private mount namespace. Keep the store writable globally inside this
  # container, while retaining nodev and nosuid hardening.
  #
  # Security tradeoff: container root can modify /nix/store directly.
  boot.nixStoreMountOpts = [
    "nodev"
    "nosuid"
  ];

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
  programs.nix-ld.enable = true;

  networking.networkmanager.enable = true;
  networking.hostName = "service";

  system.stateVersion = "25.11";

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
