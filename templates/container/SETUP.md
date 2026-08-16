# Setup & Operations: Encrypted /home

One-time provisioning and runtime procedures for the encrypted-home design
described in README.md.

## 0. Build and import the Incus image

The `lxc-container` NixOS profile produces an Incus-importable image pair:

```bash
nix build .#nixosConfigurations.service.config.system.build.metadata
meta=$(readlink result)/tarball/*.tar.xz
nix build .#nixosConfigurations.service.config.system.build.tarball
rootfs=$(readlink result)/tarball/*.tar.xz
incus image import "$meta" "$rootfs" --alias nixos-encrypted
incus create nixos-encrypted <container>
```

Note: the encrypted-home module disables sshd socket activation, so sshd
only starts after `home-ready.target` — logins are impossible (connection
refused) until the identity is injected and `/home` is mounted.

## 1. Create the external age identity

On a trusted machine (your workstation, **not** the container):

```bash
age-keygen -o encrypted-home-identity.txt
grep 'public key:' encrypted-home-identity.txt
```

Store `encrypted-home-identity.txt` somewhere safe (password manager,
hardware token, …). It is the root of trust for the container's `/home`.

Put the public key into `nix/secrets/secrets.nix`.

## 2. Create the gocryptfs key secret

Generate a random gocryptfs password and encrypt it with agenix:

```bash
nix run github:ryantm/agenix -- -e nix/secrets/home-gocryptfs-key.age \
  -i encrypted-home-identity.txt
```

The file content should be a single line with a long random password, e.g.
`pwgen -s 64 1`.

## 3. Allow FUSE in the Incus container

Host prerequisite (NixOS host firewall): the Incus bridge must be trusted,
otherwise DHCP/DNS from containers are dropped:

```nix
# on the *host*:
networking.firewall.trustedInterfaces = [ "incusbr0" ];
```

The container needs access to `/dev/fuse`:

```bash
incus config device add <container> fuse unix-char path=/dev/fuse
```

(Unprivileged containers may additionally need
`raw.apparmor: mount fstype=fuse,` depending on the host.)

Tailscale additionally needs `/dev/net/tun`:

```bash
incus config device add <container> tun unix-char path=/dev/net/tun
```

## 4. Inject the identity at runtime

The identity must land in volatile storage only (`/run` is tmpfs). After
starting the container, from the host:

```bash
incus exec <container> -- mkdir -p /run/keys
incus file push --mode 0400 encrypted-home-identity.txt \
  <container>/run/keys/encrypted-home-age-identity
```

A path unit (`encrypted-home-unlock.path`) watches for the identity file:
once it appears, agenix re-runs, gocryptfs mounts /home, and the services
that were held back (Home Manager, user@, sshd) are started automatically.

If the identity is missing, `/home` stays mode `000`, `home-ready.target`
is never reached, and Home Manager / user sessions / sshd do not start.
The boot fails closed with no plaintext fallback.

## 5. First-time initialization of the ciphertext directory

On the very first boot the ciphertext directory is still empty, so the
automatic unlock above fails at the mount step. Initialize it once:

```bash
incus exec <container> -- bash
mkdir -p /.encrypted-home
gocryptfs -init -passfile /run/agenix/home-gocryptfs-key /.encrypted-home
# Populate initial homes *inside the mounted encrypted fs*:
systemctl start encrypted-home.service
mkdir -p /home/whexy
chown whexy:users /home/whexy
chmod 0700 /home/whexy
# Re-run the unlock to start Home Manager, user managers, sshd, ...
systemctl reset-failed
systemctl start encrypted-home-unlock.service
```

Subsequent boots only require step 4 (injecting the identity); everything
else is automatic.

## 6. Routine operations

- `nixos-rebuild switch` works normally; the encrypted filesystem is
  independent of system generations.
- To rekey secrets after changing `secrets.nix`:
  `nix run github:ryantm/agenix -- -r -i encrypted-home-identity.txt`
  (run inside `nix/secrets/`).
- Backup: the Incus volume (including `/.encrypted-home`) is safe to
  snapshot/copy, but you must back up `encrypted-home-identity.txt`
  separately — without it the ciphertext is unrecoverable.

## Failure modes (by design)

| Situation                           | Result                                                                  |
| ----------------------------------- | ----------------------------------------------------------------------- |
| Identity not injected               | Boot fails closed, no plaintext fallback                                |
| gocryptfs crashes                   | `encrypted-home.service` restarts; dependent services require the mount |
| Host inspects stopped container     | Sees only `/.encrypted-home` ciphertext + the `.age` secret             |
| Identity stored on container rootfs | **Security goal defeated — never do this**                              |
