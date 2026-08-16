# Encrypted /home for NixOS Incus containers.
#
# Implements the design in README.md:
#
#   /.encrypted-home  (gocryptfs ciphertext, lives on the Incus volume)
#        │  gocryptfs, key delivered by agenix into /run
#        ▼
#   /home             (plaintext FUSE mount)
#
# The age identity used by agenix must be injected into a *volatile*
# runtime location from outside the container (see SETUP.md). It must
# never be persisted on the Incus storage volume.
{ flake, inputs }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.encrypted-home;

  # agenix installs secrets either via an activation script (which runs
  # before any systemd service during boot) or, when users are managed by
  # systemd-sysusers / userborn, via agenix-install-secrets.service.
  # Only order against the unit when it actually exists.
  agenixUsesSystemd =
    (config.systemd.sysusers.enable or false) || (config.services.userborn.enable or false);
  agenixDeps = lib.optional agenixUsesSystemd "agenix-install-secrets.service";

  keyPath = config.age.secrets.home-gocryptfs-key.path;

  targetDep = {
    requires = [ "home-ready.target" ];
    after = [ "home-ready.target" ];
  };
  homeDep = targetDep // {
    unitConfig.RequiresMountsFor = [ cfg.mountPoint ];
  };
in
{
  options.services.encrypted-home = {
    enable = lib.mkEnableOption "encrypted /home via gocryptfs and agenix";

    encryptedDir = lib.mkOption {
      type = lib.types.str;
      default = "/.encrypted-home";
      description = "Directory holding the gocryptfs ciphertext (on the Incus volume).";
    };

    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = "/home";
      description = "Mount point for the decrypted filesystem.";
    };

    secretFile = lib.mkOption {
      type = lib.types.path;
      example = ../../secrets/home-gocryptfs-key.age;
      description = ''
        age-encrypted file containing the gocryptfs password.
        Create it with `agenix -e` (see SETUP.md).
      '';
    };

    identityPath = lib.mkOption {
      type = lib.types.str;
      default = "/run/keys/encrypted-home-age-identity";
      description = ''
        Path of the externally supplied age identity. This MUST be a
        volatile (tmpfs) location populated at runtime by the Incus host,
        never a path on persistent container storage.
      '';
    };

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "whexy" ];
      description = ''
        Users whose Home Manager activation (home-manager-<user>.service)
        must wait for the encrypted filesystem.
      '';
    };

    extraDependentServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "sshd" ];
      example = [
        "sshd"
        "jellyfin"
      ];
      description = ''
        Additional services that must not start before the encrypted /home
        is available (ordered after home-ready.target). Use NixOS service
        attribute names (a trailing ".service" suffix is stripped).
      '';
    };

    gocryptfsExtraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments passed to gocryptfs.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      gocryptfs
      fuse3
      age
    ];

    # The FUSE mount is performed by root but consumed by unprivileged
    # users, so allow_other is required.
    programs.fuse.userAllowOther = true;

    # The age identity must originate outside the Incus storage volume.
    # Explicitly override agenix' default (SSH host keys under /etc/ssh),
    # which would defeat the security property of this design.
    age.identityPaths = lib.mkForce [ cfg.identityPath ];

    # The gocryptfs password, decrypted by agenix into /run (tmpfs) only.
    age.secrets.home-gocryptfs-key = {
      file = cfg.secretFile;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    # Socket-activated sshd (the default in the container profile) uses a
    # different unit (sshd@.service), which our ordering below would not
    # cover. Run sshd as a regular service instead so logins are held back
    # until the encrypted /home is mounted.
    services.openssh.startWhenNeeded = lib.mkOverride 900 false;

    systemd = {
      tmpfiles.rules = [
        # 0755, not 0700: gocryptfs presents the cipherdir's inode as the
        # mount root, so these become the permissions of /home itself.
        # The directory only holds ciphertext, so world-readability leaks
        # nothing (the host sees the ciphertext regardless).
        "d ${cfg.encryptedDir} 0755 root root - -"
        # Fail-closed: the underlying mount point is completely inaccessible,
        # so nothing can write plaintext into it while gocryptfs is absent.
        "d ${cfg.mountPoint} 0000 root root - -"
      ];

      # The stock `users` activation script recreates /home with 0755 on every
      # boot *and* every nixos-rebuild; restore the fail-closed guard whenever
      # the encrypted filesystem is not currently mounted.
      system.activationScripts.encryptedHomeGuard = {
        deps = [ "users" ];
        text = ''
          ${pkgs.util-linux}/bin/findmnt --mountpoint ${cfg.mountPoint} >/dev/null \
            || ${pkgs.coreutils}/bin/chmod 0000 ${cfg.mountPoint}
        '';
      };

      services = {
        encrypted-home = {
          description = "Mount encrypted home filesystem (gocryptfs)";

          requires = agenixDeps;
          after = agenixDeps;
          before = [ "home-ready.target" ];
          wantedBy = [ "home-ready.target" ];

          serviceConfig = {
            # Type=forking (no -fg): gocryptfs only daemonizes after the
            # filesystem is actually mounted, so the unit becomes active
            # exactly when /home is usable. If the key is missing or the
            # mount fails, the unit never reaches active and home-ready.target
            # is never reached (fail-closed).
            Type = "forking";
            ExecStart = lib.escapeShellArgs (
              [
                "${pkgs.gocryptfs}/bin/gocryptfs"
                "-allow_other"
                "-passfile"
                keyPath
                cfg.encryptedDir
                cfg.mountPoint
              ]
              ++ cfg.gocryptfsExtraArgs
            );
            # gocryptfs unmounts itself on SIGTERM; fusermount3 is a safety
            # net ("-" prefix: ignore failure if already unmounted).
            ExecStop = "-${pkgs.fuse3}/bin/fusermount3 -u ${cfg.mountPoint}";
            ExecStopPost = [
              # If gocryptfs crashed, clean up the stale FUSE connection
              # ("transport endpoint is not connected") so Restart can succeed.
              "-${pkgs.fuse3}/bin/fusermount3 -uz ${cfg.mountPoint}"
              # gocryptfs chmods the mountpoint to the cipherdir's permissions
              # when mounting; restore the fail-closed 0000 guard afterwards
              # (skipped if anything is still mounted there).
              ''-${pkgs.runtimeShell} -c "${pkgs.util-linux}/bin/findmnt --mountpoint ${cfg.mountPoint} >/dev/null || ${pkgs.coreutils}/bin/chmod 0000 ${cfg.mountPoint}"''
            ];
            Restart = "on-failure";
            RestartSec = 5;
            # Give up quickly when the key simply isn't there; boot then
            # finishes degraded-but-closed instead of blocking for minutes.
            StartLimitBurst = 3;
            TimeoutStopSec = 30;
          };
        };

        # User systemd instances (user@UID.service) must not start against
        # an unmounted home directory.
        "user@" = homeDep;

        # Triggered by the path unit below when the identity appears.
        encrypted-home-unlock = {
          description = "Complete encrypted-home unlock after age identity injection";
          serviceConfig.Type = "oneshot";
          script =
            let
              # agenix either runs as an activation script or as a systemd
              # service; redo whichever applies so the secret lands in /run.
              installSecrets =
                if agenixUsesSystemd then
                  "systemctl restart agenix-install-secrets.service"
                else
                  "/run/current-system/activate";
              userServices = lib.concatMapStringsSep "\n" (
                u: ''systemctl start "user@$(${pkgs.coreutils}/bin/id -u ${u}).service" || true''
              ) cfg.users;
            in
            ''
              ${installSecrets}
              systemctl reset-failed encrypted-home.service || true
              systemctl start home-ready.target
              # Start consumers that were held back during the fail-closed boot.
              # Best-effort: e.g. on first boot home-manager fails until the
              # user's home directory is created inside the fresh filesystem
              # (see SETUP.md). Their state stays visible in systemctl --failed.
              ${lib.concatMapStringsSep "\n" (u: "systemctl start home-manager-${u}.service || true") cfg.users}
              ${userServices}
              ${lib.concatMapStringsSep "\n" (
                s: "systemctl start ${lib.removeSuffix ".service" s}.service || true"
              ) cfg.extraDependentServices}
            '';
        };
      }
      # Home Manager activation only runs against the decrypted /home.
      // lib.genAttrs (map (u: "home-manager-${u}") cfg.users) (_: homeDep)
      # Login paths (e.g. sshd) and other home-dependent services.
      # Login paths (e.g. sshd) and other home-dependent services. The
      # ".service" suffix is stripped so the definition merges with the
      # service's own NixOS definition instead of creating a conflicting
      # unit of the same name.
      // lib.genAttrs (map (s: lib.removeSuffix ".service" s) cfg.extraDependentServices) (_: targetDep);

      # Stable synchronization point: consumers depend on this target rather
      # than on gocryptfs implementation details.
      targets.home-ready = {
        description = "Encrypted home filesystem is available";
        requires = [ "encrypted-home.service" ];
        after = [ "encrypted-home.service" ];
        wantedBy = [ "multi-user.target" ];
      };

      # The age identity is typically injected *after* boot (e.g. via
      # `incus file push` into tmpfs), but agenix ran during early boot.
      # Watch for the identity and complete the unlock automatically:
      # re-install secrets, mount /home, and start the services that were
      # held back by the fail-closed boot.
      paths.encrypted-home-unlock = {
        description = "Trigger encrypted-home unlock when the age identity appears";
        wantedBy = [ "multi-user.target" ];
        pathConfig.PathExists = cfg.identityPath;
      };
    };
  };
}
