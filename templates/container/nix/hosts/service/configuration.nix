{
  flake,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware.nix
    inputs.agenix.nixosModules.default
    flake.modules.nixos.encrypted-home
  ];

  services = {
    # Encrypted /home (gocryptfs + agenix, see README.md and SETUP.md).
    encrypted-home = {
      enable = true;
      secretFile = ../../secrets/home-gocryptfs-key.age;
      users = [ "whexy" ];
    };

    resolved.enable = true;

    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
    };

    # Requires /dev/net/tun inside the container, e.g.:
    #   incus config device add <container> tun unix-char path=/dev/net/tun
    tailscale.enable = true;
  };

  nixpkgs.hostPlatform = "x86_64-linux";

  nix.settings.require-sigs = false;

  users.users.whexy = {
    isNormalUser = true;
    home = "/home/whexy";
    # The real home directory lives inside the encrypted filesystem;
    # never create a plaintext one on the Incus volume.
    createHome = false;
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

  # Incus provides the NIC (veth); DHCP and DNS via systemd-networkd /
  # systemd-resolved. NetworkManager does not belong inside a container.
  networking = {
    hostName = "service";
    useDHCP = true;
    useNetworkd = true;
    useHostResolvConf = lib.mkForce false;
  };
  home-manager.sharedModules = [
    inputs.agenix.homeManagerModules.default
    flake.modules.home.myservice
  ];

  security.sudo.wheelNeedsPassword = false;
}
