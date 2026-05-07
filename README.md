# StorageGraft

StorageGraft is a Linux storage-extension reconciler.

It helps systems with constrained local storage use larger mounted stores by relocating selected filesystem subtrees into those stores, then bind-mounting the store-backed subtrees back onto their original addresses.

Applications keep using the same paths. The data lives on the larger store.

## Why

Some Linux environments run from small filesystems that are difficult, risky, or inconvenient to resize. Larger storage may be available separately through removable media, disk images, physical devices, network filesystems, distributed filesystems, FUSE mounts, pooled filesystems, or other mounted stores.

StorageGraft provides a repeatable way to move selected high-growth directories out of the constrained filesystem while preserving the visible filesystem layout.

## Core idea

Given an origin address and a store root:

```text
store subtree = store root + origin address
```

Example:

```text
origin address:
  /home/<user>/example

store root:
  /mnt/store

store subtree:
  /mnt/store/home/<user>/example
```

StorageGraft migrates or merges the contents of the origin address into the store subtree, verifies the result, and then bind-mounts the store subtree back onto the origin address:

```text
/mnt/store/home/<user>/example
  mounted at
/home/<user>/example
```

The visible address remains the same. The storage backing it changes.

## Stores

A store is any mounted filesystem that can provide storage for grafted subtrees.

A store may be backed by a loop-mounted disk image, a physical device, a partition, an LVM logical volume, a Btrfs filesystem, a ZFS dataset, an NFS share, a CephFS mount, a FUSE filesystem, a mergerfs pool, or another mounted storage system.

StorageGraft does not replace those systems. It uses their mounted filesystems as storage targets.

## Grafts

A graft connects an origin address to a corresponding store subtree.

For example:

```text
/home/<user>/example
```

can be grafted into:

```text
/mnt/store/home/<user>/example
```

and then exposed back at:

```text
/home/<user>/example
```

This is implemented with standard Linux bind mounts.

## Configuration

StorageGraft configuration is organized around named stores.

The configuration model is holonic: the user configuration tree mirrors the system configuration tree. Each plane has its own main configuration file, store declarations, and path declarations.

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

The store name is the join key.

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

## Store configuration format

Store configuration files use simple `key=value` syntax.

Example:

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

## Path lists

A path list contains origin address entries, one per line.

Blank lines are ignored.

Lines beginning with `#` are ignored.

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

Example user entries:

```text
example
./example
/home/<user>/example
```

all resolve to:

```text
/home/<user>/example
```

After resolution, StorageGraft computes the store subtree:

```text
store subtree = store root + resolved origin address
```

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

StorageGraft is designed to avoid hiding existing data behind bind mounts before migration or merge verification has completed.

## Current implementation

The current implementation is a strict POSIX shell script.

Implemented commands:

```text
storagegraft check
storagegraft status [store]
storagegraft plan [store]
```

These commands are non-mutating. They do not migrate data, activate bind mounts, clear origin contents, or generate systemd units.

The current planner can:

```text
read system configuration
read user configuration
discover system stores
discover user stores
read system path lists
read user path lists
resolve relative path entries
compute store subtrees
inspect mounted stores
classify origin and store subtree state
report planned actions
```

Mutation commands such as `apply` and `reconcile` are not implemented yet.

## Requirements

The implementation target is:

```text
/bin/sh
strict POSIX shell
BusyBox-conscious utilities where practical
systemd for managed lifecycle integration
standard Linux mount tooling
```

StorageGraft does not require Bash, Zsh, Python, Perl, or another scripting runtime.

## Basic usage

From a checkout:

```text
./sbin/storagegraft.sh check
./sbin/storagegraft.sh status
./sbin/storagegraft.sh plan
```

To inspect one store:

```text
./sbin/storagegraft.sh status main
./sbin/storagegraft.sh plan main
```

The script reads system configuration from:

```text
/etc/storagegraft/
```

For development or testing, the system configuration root can be overridden:

```text
STORAGEGRAFT_ETC=/path/to/test/etc ./sbin/storagegraft.sh plan
```

## Project boundary

StorageGraft is not a filesystem, volume manager, storage backend, distributed storage system, or loop-device wrapper.

StorageGraft composes existing storage and mount mechanisms into a storage-graft workflow:

```text
mounted stores
resolved origin addresses
computed store subtrees
safe migration or merge
bind-mount exposure
systemd-native lifecycle integration
```