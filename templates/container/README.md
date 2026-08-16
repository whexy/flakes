# Encrypted Home Storage for NixOS Incus Containers

## 1. Motivation

Incus system containers commonly use host-managed storage such as an LVM-backed storage pool. For containers, Incus mounts the container root filesystem on the host and exposes it to the container through the container's mount namespace.

This creates an important difference from virtual machines.

A VM can receive an opaque block device and place a guest-controlled encryption layer such as LUKS on top of it. The host may access the raw block device, but without the guest encryption key it cannot directly interpret the guest filesystem while the VM is stopped.

An Incus container does not normally have this property. Its root filesystem is a filesystem managed and mounted by the host. Consequently, anyone capable of accessing or mounting the Incus storage volume can inspect the container root filesystem.

For a NixOS system container, however, most of the operating system does not need to be confidential. The system is largely reproducible from the Nix configuration:

- `/nix/store` contains immutable system and package contents.
- `/etc` is primarily generated from the NixOS configuration.
- systemd configuration is declaratively generated.
- installed packages and services can be reconstructed with `nixos-rebuild`.
- much of `/var` can either be treated as disposable or selectively persisted.

The most sensitive and difficult-to-reconstruct data is typically located under `/home`, including:

- source code and research data;
- SSH keys and other credentials;
- shell and application configuration;
- browser profiles;
- personal documents;
- development state;
- application-specific secrets.

The goal is therefore not to encrypt the complete Incus container root filesystem. Instead, the design introduces a separate encryption boundary for the complete `/home` hierarchy.

The desired security property is:

> Possession of the stopped Incus container storage must not, by itself, be sufficient to recover the contents of `/home`.

This design primarily protects against offline access to container storage, including:

- direct mounting of the Incus LVM logical volume;
- inspection of an Incus backup or snapshot;
- theft or copying of the backing storage;
- administrative access to the stopped container filesystem without access to the external decryption identity.

This design does **not** attempt to protect plaintext from a malicious Incus host while the container is running. Because containers share the host kernel, a sufficiently privileged host administrator can inspect the container's mount namespace, processes, memory, or FUSE filesystem.

For protection against a malicious running host, a VM or confidential-computing mechanism would be required.

---

## 2. Design

### 2.1 High-Level Architecture

The NixOS container root filesystem remains a normal Incus-managed filesystem.

The container contains two locations related to home storage:

```text
/
├── nix/
├── etc/
├── var/
├── home/                  # plaintext FUSE mount point
└── .encrypted-home/       # persistent ciphertext
```

`/.encrypted-home` is stored directly inside the Incus root filesystem and therefore remains visible to the host. However, it contains only encrypted gocryptfs data.

At runtime, the container obtains a gocryptfs key through agenix and mounts:

```text
/.encrypted-home
        │
        │ gocryptfs
        ▼
      /home
```

Applications and users interact exclusively with `/home`.

The Incus storage layer therefore contains:

```text
Incus LVM volume
│
└── NixOS rootfs
    ├── /nix
    ├── /etc
    ├── /var
    ├── /home              # empty/inaccessible while locked
    └── /.encrypted-home   # ciphertext only
```

while the running container sees:

```text
/home
├── wenxuan/
│   ├── .ssh/
│   ├── .config/
│   ├── projects/
│   └── ...
└── ...
```

### 2.2 Encryption Stack

The encryption hierarchy is:

```text
/home contents
      │
      │ encrypted by
      ▼
  gocryptfs
      │
      │ key encrypted by
      ▼
    agenix
      │
      │ decrypted using
      ▼
 external age identity
```

The gocryptfs password or key is stored as an age-encrypted secret in the NixOS configuration.

For example:

```text
secrets/home-gocryptfs-key.age
```

Agenix decrypts this secret during container startup and places the plaintext key in a volatile runtime location such as:

```text
/run/agenix/home-gocryptfs-key
```

The plaintext key must never be written into the persistent Incus root filesystem.

### 2.3 External Root of Trust

A critical requirement is that the age private identity used by agenix **must not be stored on the same Incus filesystem being protected**.

A normal agenix deployment often derives its age identity from the system SSH host key:

```text
/etc/ssh/ssh_host_ed25519_key
```

That would defeat the intended security property. An attacker with access to the Incus volume would obtain all three components:

```text
SSH private key
+
home-gocryptfs-key.age
+
.encrypted-home
```

and could therefore recover `/home`.

Instead, the age identity must originate outside the persistent Incus storage.

Possible trust roots include:

1. a key supplied to the container at runtime by the Incus host;
2. a remote secret-management service;
3. a hardware-backed key;
4. a manually supplied age identity;
5. a TPM-backed mechanism, where practical.

The minimal acceptable design is:

```text
Incus persistent storage
        │
        ├── encrypted agenix secret
        └── encrypted gocryptfs data

External runtime source
        │
        └── age identity
```

Therefore:

```text
Incus storage alone
        ↓
insufficient to decrypt /home
```

### 2.4 Boot Dependency Graph

The encrypted home filesystem must become available before anything that expects a usable home directory.

The intended boot sequence is:

```text
Incus starts container
        │
        ▼
NixOS systemd starts
        │
        ▼
external age identity becomes available
        │
        ▼
agenix decrypts home key
        │
        ▼
gocryptfs mounts /home
        │
        ▼
home-ready.target
        │
        ├── Home Manager activation
        ├── user@UID.service
        ├── SSH user logins
        └── services requiring /home
```

This ordering must be explicit rather than incidental.

The conceptual systemd dependency graph is:

```text
agenix-install-secrets.service
             │
             ▼
encrypted-home.service
             │
             ▼
home-ready.target
             │
             ├── home-manager-*.service
             ├── user@*.service
             └── other home-dependent services
```

### 2.5 Fail-Closed Behavior

A particularly important requirement is that failure to mount the encrypted filesystem must **not** result in services silently writing plaintext into the underlying `/home` directory.

Without protection, the following failure is possible:

```text
gocryptfs mount fails
        ↓
/home remains an ordinary directory
        ↓
Home Manager or another service starts
        ↓
files are written to /home
        ↓
plaintext ends up in Incus storage
```

The system must therefore fail closed.

The underlying `/home` mount point should be unusable when gocryptfs is absent. For example, it can be owned by root and have permissions such as:

```text
000
```

The FUSE mount replaces those underlying permissions while mounted.

Services that require `/home` should additionally use explicit systemd dependencies such as:

```text
RequiresMountsFor=/home
```

and depend on the encrypted-home service.

The resulting behavior should be:

```text
Encryption available
        ↓
/home mounted
        ↓
user services start
```

versus:

```text
Encryption unavailable
        ↓
/home inaccessible
        ↓
user services remain stopped/fail
        ↓
no plaintext fallback
```

### 2.6 Runtime Security Boundary

While the container is stopped:

```text
Host sees:

/
├── nix/
├── etc/
├── var/
├── home/                # no plaintext content
└── .encrypted-home/
    └── ciphertext
```

Assuming the age identity is unavailable, `/home` cannot be reconstructed from the Incus storage alone.

While the container is running:

```text
gocryptfs process
     │
     ├── holds key in memory
     └── exposes plaintext /home
```

At this point the design does not protect against malicious host root. The host may be able to:

- enter the container's mount namespace;
- access the active FUSE mount;
- inspect the gocryptfs process;
- inspect container memory;
- tamper with the container.

This is an accepted limitation of the container threat model.

### 2.7 Shutdown Ordering

Shutdown should occur in reverse dependency order:

```text
user sessions/services stop
        │
        ▼
Home Manager-dependent services stop
        │
        ▼
/home no longer in use
        │
        ▼
gocryptfs unmounts /home
        │
        ▼
agenix runtime secret disappears
        │
        ▼
container stops
```

The gocryptfs service should refuse or fail visibly if `/home` remains busy instead of forcing an unsafe shutdown unless explicitly configured otherwise.

---

## 3. Proposed Implementation

### 3.1 Packages

The NixOS container requires at least:

```nix
environment.systemPackages = with pkgs; [
  gocryptfs
  fuse3
  age
];
```

Agenix is included through the system's existing flake/module configuration.

### 3.2 Agenix Secret

The gocryptfs password is represented as an agenix secret:

```nix
age.secrets.home-gocryptfs-key = {
  file = ./secrets/home-gocryptfs-key.age;
  owner = "root";
  group = "root";
  mode = "0400";
};
```

The resulting runtime path is referenced through:

```nix
config.age.secrets.home-gocryptfs-key.path
```

rather than hard-coding a path.

The age private identity used to decrypt this secret must be supplied externally and must not be persisted on the Incus storage volume.

### 3.3 Filesystem Layout

The encrypted backing directory is:

```text
/.encrypted-home
```

The decrypted mount point is:

```text
/home
```

Initialization is performed once:

```bash
gocryptfs -init /.encrypted-home
```

using the same secret that will later be delivered through agenix.

The underlying `/home` directory should then be protected:

```text
owner: root
group: root
mode: 000
```

so accidental plaintext writes are impossible while the encrypted filesystem is absent.

### 3.4 gocryptfs systemd Service

A dedicated service mounts the encrypted filesystem.

Conceptually:

```nix
systemd.services.encrypted-home = {
  description = "Mount encrypted home filesystem";

  requires = [
    "agenix-install-secrets.service"
  ];

  after = [
    "agenix-install-secrets.service"
  ];

  before = [
    "home-ready.target"
  ];

  wantedBy = [
    "home-ready.target"
  ];

  serviceConfig = {
    Type = "simple";

    ExecStart = ''
      ${pkgs.gocryptfs}/bin/gocryptfs \
        -fg \
        -passfile ${config.age.secrets.home-gocryptfs-key.path} \
        /.encrypted-home \
        /home
    '';

    ExecStop = ''
      ${pkgs.fuse3}/bin/fusermount3 -u /home
    '';

    Restart = "on-failure";
  };
};
```

The exact agenix service dependency should be verified against the installed agenix version rather than relying on a hard-coded unit name if agenix exposes a more appropriate dependency mechanism.

### 3.5 Dedicated `home-ready.target`

A custom systemd target provides a stable synchronization point:

```nix
systemd.targets.home-ready = {
  description = "Encrypted home filesystem is available";

  requires = [
    "encrypted-home.service"
  ];

  after = [
    "encrypted-home.service"
  ];
};
```

Anything requiring `/home` should start after this target.

This avoids coupling unrelated services directly to implementation details such as gocryptfs.

The abstraction becomes:

```text
consumer
   ↓
home-ready.target
```

instead of:

```text
consumer
   ↓
gocryptfs-specific service
```

### 3.6 Home Manager Ordering

Home Manager activation must only occur after `/home` exists as the encrypted filesystem.

For the generated Home Manager unit, the intended dependency is equivalent to:

```nix
{
  requires = [ "home-ready.target" ];
  after = [ "home-ready.target" ];

  unitConfig.RequiresMountsFor = "/home";
}
```

The precise generated unit name should be determined from the Home Manager NixOS module configuration.

For example, it may resemble:

```text
home-manager-wenxuan.service
```

The important property is:

```text
/home unavailable
        ⇒
Home Manager activation does not run
```

Home Manager may therefore safely manage arbitrary contents underneath the encrypted filesystem:

```text
/home/wenxuan/.config
/home/wenxuan/.ssh
/home/wenxuan/.local
...
```

### 3.7 User Manager Ordering

User systemd instances should similarly wait for `/home`.

Conceptually:

```text
home-ready.target
        ↓
user@1000.service
```

This prevents user services from starting against an unmounted home directory.

SSH and other login paths should also be arranged such that normal user sessions cannot begin until encrypted home storage is ready.

### 3.8 NixOS User Definition

The user account itself remains declarative and does not require `/home` to exist during early boot.

For example:

```nix
users.users.wenxuan = {
  isNormalUser = true;
  home = "/home/wenxuan";
  createHome = false;
};
```

The actual home directory is persisted inside the encrypted filesystem.

This cleanly separates:

```text
user identity
    │
    └── NixOS configuration

user data
    │
    └── encrypted /home
```

### 3.9 NixOS Rebuild Behavior

`nixos-rebuild` continues to operate normally.

A system rebuild modifies or creates Nix store paths and updates the active NixOS generation:

```text
/nix/store/<new-system>
        ↓
/run/current-system
```

The encrypted `/home` filesystem is independent of this process.

Therefore:

```text
nixos-rebuild switch
        │
        ├── updates operating system
        └── does not migrate or rewrite encrypted home storage
```

Home Manager activation resulting from the switch must still obey the `/home` dependency described above.

### 3.10 External Age Identity Delivery

The initial implementation can use a runtime-injected age identity.

Conceptually:

```text
Incus starts container
        │
        ▼
identity supplied into volatile runtime storage
        │
        ▼
agenix uses identity
        │
        ▼
home key appears in /run
```

The identity must never be copied into a persistent filesystem location such as:

```text
/etc
/root
/var/lib
/nix/store
```

Potential future implementations may replace runtime injection with:

- Vault or another secret-management service;
- TPM-backed unsealing;
- network-bound decryption;
- hardware-token-backed age identities.

The rest of the encrypted-home architecture should remain unchanged.

---

## 4. Security Properties

The proposed system provides the following properties.

| Threat / Scenario                                     | Protection                          |
| ----------------------------------------------------- | ----------------------------------- |
| Incus LV mounted while container is stopped           | `/home` remains encrypted           |
| Incus snapshot inspected                              | `/home` remains encrypted           |
| Raw backing storage copied                            | `/home` remains encrypted           |
| Incus backup copied                                   | `/home` remains encrypted           |
| Attacker has ciphertext but not external age identity | Cannot recover gocryptfs key        |
| gocryptfs mount fails                                 | Home-dependent services fail closed |
| `nixos-rebuild` runs                                  | Encryption remains independent      |
| Malicious host root while container is running        | **Not protected**                   |
| Host extracts container RAM while running             | **Not protected**                   |
| Age identity stored on Incus rootfs                   | **Security goal defeated**          |

The central invariant is:

```text
decrypt(/home)
requires:

    Incus encrypted data
  + agenix encrypted secret
  + external age identity
```

Only the first two components are stored on the Incus volume.

---

## 5. Final Architecture

```text
                         External trust root
                                │
                          age identity
                                │
                                ▼
                    ┌─────────────────────┐
                    │      agenix         │
                    └──────────┬──────────┘
                               │
                               │ plaintext key
                               │ only in /run
                               ▼
                    ┌─────────────────────┐
                    │     gocryptfs       │
                    └──────────┬──────────┘
                               │
                 ┌─────────────┴─────────────┐
                 │                           │
              ciphertext                 plaintext
                 │                           │
                 ▼                           ▼
       /.encrypted-home                   /home
                 │                           │
                 │                    ┌──────┴───────┐
                 │                    │              │
                 │               Home Manager    user services
                 │
                 ▼
          Incus root filesystem
                 │
                 ▼
             LVM storage
```

The corresponding startup invariant is:

```text
external identity
        ↓
agenix secret available
        ↓
encrypted /home mounted
        ↓
home-ready.target reached
        ↓
Home Manager + users + applications
```

This preserves the convenience of a fully declarative NixOS system container while ensuring that the primary user-data hierarchy is not recoverable from the Incus storage volume alone.
