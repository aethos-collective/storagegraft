# Architecture

StorageGraft is a storage-graft reconciler for Linux.

It composes existing filesystem, mount, and service-management primitives to relocate selected filesystem subtrees into one or more mounted stores while preserving their original visible addresses.

StorageGraft does not provide storage by itself. It uses storage that already exists or can be mounted by standard Linux tools.

## Core objects

### Store

A store is a mounted filesystem that can provide storage for grafted subtrees.

A store may be backed by a disk image, loop device, physical device, partition, LVM logical volume, Btrfs filesystem, ZFS dataset, network filesystem, distributed filesystem, FUSE mount, pooled filesystem, or another mounted storage system.

StorageGraft treats the mounted store root as the usable boundary.

### Store root

A store root is the mount point of a store.

Example:

```text
/mnt/store
```

The store root is the prefix used to construct store subtrees.

### Origin address

An origin address is the resolved filesystem address that applications already use.

Example:

```text
/home/<user>/example
```

The origin address identifies where the graft appears.

Path-list entries may be absolute or relative. StorageGraft resolves each entry before treating it as an origin address.

### Store subtree

A store subtree is the corresponding location inside a store.

StorageGraft computes it by prepending the store root to the resolved origin address:

```text
store subtree = store root + resolved origin address
```

Example:

```text
store root:
  /mnt/store

resolved origin address:
  /home/<user>/example

store subtree:
  /mnt/store/home/<user>/example
```

### Graft

A graft is the bind mount that makes the store subtree visible at the origin address.

Example:

```text
mount --bind /mnt/store/home/<user>/example /home/<user>/example
```

The data lives under the store. Applications continue using the origin address.

## Configuration model

StorageGraft configuration is holonic.

The user configuration tree mirrors the system configuration tree. Each plane has its own main configuration file, store declarations, and path declarations.

System configuration:

```text
/etc/storagegraft/
├── storagegraft.conf
├── stores.d/
│   └── <store>.conf
└── paths.d/
    └── <store>.paths
```

User configuration:

```text
/home/<user>/.storagegraft/
├── storagegraft.conf
├── stores.d/
│   └── <store>.conf
└── paths.d/
    └── <store>.paths
```

The system plane defines system-wide defaults, system stores, system path declarations, and authoritative policy.

The user plane defines user-level defaults, user stores, and user path declarations, subject to system policy.

## Store naming

Stores are declared by name.

The store name is the key that connects store configuration to path lists.

For a system store named `main`:

```text
/etc/storagegraft/stores.d/main.conf
/etc/storagegraft/paths.d/main.paths
```

For a user store named `main`:

```text
/home/<user>/.storagegraft/stores.d/main.conf
/home/<user>/.storagegraft/paths.d/main.paths
```

The file name determines the store name.

A file named:

```text
main.conf
```

declares a store named:

```text
main
```

A file named:

```text
main.paths
```

declares origin address entries for the store named:

```text
main
```

## Configuration format

StorageGraft configuration files use simple `key=value` syntax.

Example store configuration:

```text
root=/mnt/store
activation=external
managed=false
kind=filesystem
semantics=posix
durability=backend-defined
graft_mode=bind
migration=direct-verified
conflict=refuse
users=allow
user_scope=home-only
```

Blank lines are ignored.

Lines beginning with `#` are ignored.

## Path lists

A path list is a plain text file containing origin address entries, one per line.

Example:

```text
# Example path list
example
.cache/example
/home/<user>/example
```

Path-list entries may be absolute or relative.

System path-list entries resolve relative to:

```text
/
```

User path-list entries resolve relative to the declaring user’s home directory.

For a user whose home directory is:

```text
/home/<user>
```

these entries are equivalent:

```text
example
./example
/home/<user>/example
```

They resolve to:

```text
/home/<user>/example
```

For a system path list, these entries are equivalent:

```text
usr/local
/usr/local
```

They resolve to:

```text
/usr/local
```

After resolution, StorageGraft computes the store subtree from the resolved origin address.

## System stores and user stores

A system store is declared under:

```text
/etc/storagegraft/stores.d/
```

A user store is declared under:

```text
/home/<user>/.storagegraft/stores.d/
```

System stores are root-owned declarations.

User stores are user-owned declarations. They are not automatically trusted as privileged authority.

A system store may serve system path declarations and user path declarations when policy allows it.

A user store normally serves only that user’s allowed origin addresses.

By default, a user-declared store does not graft system paths.

## System paths and user paths

A system path list is declared under:

```text
/etc/storagegraft/paths.d/
```

A user path list is declared under:

```text
/home/<user>/.storagegraft/paths.d/
```

System path lists are root-owned policy.

User path lists are user-owned declarations. The reconciler validates them before use.

Under the default `home-only` user scope, user path declarations resolve within the declaring user’s home directory.

## Lifecycle

StorageGraft is systemd-native.

systemd owns lifecycle, activation, ordering, retry behavior, and unit state wherever possible.

StorageGraft supplies configuration, planning, validation, migration policy, merge policy, reconciliation, and generated unit material when needed.

For managed stores, StorageGraft uses or generates systemd units such as:

```text
.mount
.path
.timer
.automount
.service
```

Mount units are named according to the mount point they control, as required by systemd. StorageGraft store names do not replace systemd mount-unit naming.

## Managed and unmanaged stores

A managed store is brought online through StorageGraft-managed systemd configuration.

Example:

```text
a disk image mounted at /mnt/store with mount -o loop
```

An unmanaged store is mounted by something outside StorageGraft.

Examples:

```text
administrator-managed filesystem
physical disk mount
NFS mount
CephFS mount
FUSE mount
mergerfs pool
Hyperdrive FUSE mount
IPFS MFS mount
```

StorageGraft uses either kind as long as the store is mounted and suitable for the requested grafts.

## Reconciliation

StorageGraft reconciles declared grafts against current system state.

Reconciliation reads:

```text
system main configuration
system store declarations
system path declarations
user main configuration
user store declarations
user path declarations
```

It then:

1. verifies store readiness
2. validates declared origin address entries
3. resolves relative entries
4. computes store subtrees
5. detects conflicts
6. plans migrations or merges
7. verifies completed data movement when applying changes
8. activates bind mounts when applying changes
9. reports status

## Safety model

StorageGraft is plan-first.

Before changing storage state, it determines whether each graft is safe to apply:

```text
origin is empty, store subtree is empty:
  create and bind

origin is empty, store subtree has data:
  bind

origin has data, store subtree is empty:
  migrate, verify, then bind

origin has data, store subtree has data, no conflicts:
  merge, verify, then bind

origin has data, store subtree has conflicting data:
  stop and require a manual merge decision

already grafted:
  no action
```

A conflict occurs when the same relative address exists in both the origin and the store subtree and StorageGraft cannot safely combine them without overwriting, replacing, or changing the type of an existing filesystem object.

## Separation of concerns

StorageGraft owns:

- store declarations
- path declarations
- planning
- validation
- migration and merge policy
- conflict detection
- bind-graft reconciliation
- status reporting
- generated unit material when needed

StorageGraft does not replace:

- `mount`
- bind mounts
- `/etc/fstab`
- systemd mount units
- loop devices
- LVM
- Btrfs
- ZFS
- RAID
- NFS
- CephFS
- FUSE
- mergerfs
- OverlayFS
- bindfs
- distributed storage systems

Those systems provide storage, mounts, pooling, distribution, or filesystem semantics. StorageGraft composes them.

## Current implementation boundary

The current implementation is a strict POSIX shell script.

Implemented commands:

```text
storagegraft check
storagegraft status [store]
storagegraft plan [store]
```

These commands are non-mutating. They do not migrate data, activate bind mounts, clear origin contents, or generate systemd units.

Mutation behavior belongs to later implementation phases after planning, validation, and conflict detection are reliable.