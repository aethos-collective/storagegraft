# Terminology

This document defines the core terms used by StorageGraft.

StorageGraft uses ordinary Linux storage and mount terminology wherever possible. Project-specific terms describe StorageGraft’s own reconciliation model.

## Store

A store is a mounted filesystem that can provide storage for grafted subtrees.

A store may be backed by a physical device, partition, disk image, loop device, LVM logical volume, Btrfs filesystem, ZFS dataset, network filesystem, distributed filesystem, FUSE mount, pooled filesystem, or another mounted storage system.

StorageGraft treats the mounted store root as the usable boundary.

Example:

```text
/mnt/store
```

## Store root

A store root is the mount point of a store.

Example:

```text
/mnt/store
```

The store root is the prefix used to construct store subtrees.

## Origin address entry

An origin address entry is a line in a path list.

An origin address entry may be absolute or relative.

Example entries:

```text
example
./example
/home/<user>/example
```

StorageGraft resolves origin address entries before planning grafts.

## Origin address

An origin address is the resolved filesystem address that applications already use.

Example:

```text
/home/<user>/example
```

The origin address identifies where the graft appears.

The origin address may already contain data before StorageGraft acts on it.

## Relative path resolution

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

## Store subtree

A store subtree is the corresponding location inside a store.

StorageGraft computes the store subtree by prepending the store root to the resolved origin address:

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

## Graft

A graft is the completed relationship between an origin address and a store subtree.

StorageGraft uses a bind mount to make the store subtree visible at the origin address.

Example:

```text
mount --bind /mnt/store/home/<user>/example /home/<user>/example
```

After the graft is active, applications continue to use:

```text
/home/<user>/example
```

while the data resides under:

```text
/mnt/store/home/<user>/example
```

## Bind mount

A bind mount is the Linux mount operation used to expose one directory tree at another location.

StorageGraft’s standard bind direction is:

```text
mount --bind <store subtree> <origin address>
```

Example:

```text
mount --bind /mnt/store/home/<user>/example /home/<user>/example
```

## Configuration plane

A configuration plane is a self-contained StorageGraft configuration tree.

StorageGraft has two configuration planes:

```text
system plane
user plane
```

The system plane lives under:

```text
/etc/storagegraft/
```

The user plane lives under:

```text
/home/<user>/.storagegraft/
```

Each plane has the same shape:

```text
storagegraft.conf
stores.d/
paths.d/
```

## System plane

The system plane defines system-wide defaults, system stores, system path declarations, and authoritative policy.

System configuration layout:

```text
/etc/storagegraft/
├── storagegraft.conf
├── stores.d/
│   └── <store>.conf
└── paths.d/
    └── <store>.paths
```

System configuration is root-owned policy.

## User plane

The user plane defines user-level defaults, user stores, and user path declarations, subject to system policy.

User configuration layout:

```text
/home/<user>/.storagegraft/
├── storagegraft.conf
├── stores.d/
│   └── <store>.conf
└── paths.d/
    └── <store>.paths
```

User configuration contributes declarations. It does not grant itself privileged authority.

## Main configuration file

A main configuration file defines defaults and policy for a configuration plane.

System main configuration:

```text
/etc/storagegraft/storagegraft.conf
```

User main configuration:

```text
/home/<user>/.storagegraft/storagegraft.conf
```

Main configuration files use simple `key=value` syntax.

Example:

```text
default_activation=external
default_graft_mode=bind
default_migration=direct-verified
default_conflict=refuse
```

## Store configuration

A store configuration describes a named store.

System store configuration:

```text
/etc/storagegraft/stores.d/<store>.conf
```

User store configuration:

```text
/home/<user>/.storagegraft/stores.d/<store>.conf
```

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

## Store name

A store name is the join key connecting a store configuration file to matching path-list files.

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

## Path list

A path list is a plain text file containing origin address entries, one per line.

Blank lines are ignored.

Lines beginning with `#` are ignored.

Example:

```text
# example path list
example
.cache/example
/home/<user>/example
/var/cache/example
```

Path lists are named after stores.

System path list:

```text
/etc/storagegraft/paths.d/<store>.paths
```

User path list:

```text
/home/<user>/.storagegraft/paths.d/<store>.paths
```

## System store

A system store is declared under:

```text
/etc/storagegraft/stores.d/
```

A system store is a root-owned store declaration.

A system store may serve system path declarations and user path declarations when policy allows it.

## User store

A user store is declared under:

```text
/home/<user>/.storagegraft/stores.d/
```

A user store is a user-owned store declaration.

A user store normally serves only that user’s allowed origin addresses.

By default, a user-declared store does not graft system paths.

## System path declaration

A system path declaration is an origin address entry from a root-owned system path list.

System path lists live under:

```text
/etc/storagegraft/paths.d/
```

System relative entries resolve against:

```text
/
```

## User path declaration

A user path declaration is an origin address entry from a user-owned path list.

User path lists live under:

```text
/home/<user>/.storagegraft/paths.d/
```

User relative entries resolve against the declaring user’s home directory.

Under the default `home-only` scope, user declarations resolve within the declaring user’s home directory.

## Managed store

A managed store is brought online by StorageGraft-managed systemd configuration.

Example use cases include disk images, loop-mounted filesystems, or other stores whose lifecycle StorageGraft coordinates through systemd units.

A managed store may use systemd units such as:

```text
.mount
.path
.timer
.automount
.service
```

## Unmanaged store

An unmanaged store is mounted by something outside StorageGraft.

Examples include administrator-managed mounts, NFS mounts, CephFS mounts, FUSE mounts, mergerfs pools, physical devices, or other filesystems already available at a mount point.

StorageGraft can use unmanaged stores when they are mounted and suitable for the requested grafts.

## Reconciliation

Reconciliation is the process of comparing declared grafts against current system state and determining what actions are required.

Reconciliation includes:

- checking store readiness
- validating origin address entries
- resolving relative entries
- computing store subtrees
- detecting conflicts
- planning migration or merge actions
- verifying copied data when applying changes
- activating bind mounts when applying changes
- reporting status

## Migration

Migration moves data from an origin address into the corresponding store subtree.

Migration is used when the origin address already contains data and the store subtree is empty or absent.

StorageGraft verifies the result before clearing origin contents.

## Merge

A merge moves non-conflicting origin contents into a store subtree that already contains data.

A merge is allowed only when StorageGraft can combine the two trees without overwriting, replacing, or changing the type of an existing filesystem object.

## Conflict

A conflict occurs when the same relative address exists in both the origin and the store subtree and StorageGraft cannot safely combine them.

Examples include:

```text
same file exists on both sides
file exists on one side and directory exists on the other
symlink exists on one side and regular file exists on the other
filesystem object type mismatch
unsupported special file collision
```

When a conflict is detected, StorageGraft stops and requires a manual merge decision.

## Plan

A plan is StorageGraft’s proposed action set before changing storage state.

A plan reports:

- stores
- store readiness
- origin addresses
- store subtrees
- migration requirements
- merge requirements
- conflicts
- bind actions
- refused actions

The current implementation provides `storagegraft plan` as a non-mutating command.

## Apply

Apply executes a verified plan.

Apply may create directories, migrate data, merge data, clear origin contents after verification, and activate bind mounts.

Apply is not implemented in the current POSIX shell planner.

## Status

Status reports current StorageGraft state.

Status may include:

- mounted stores
- missing stores
- active grafts
- pending grafts
- conflicts
- hidden origin content risks
- failed mounts
- store suitability warnings

The current implementation provides `storagegraft status` as a non-mutating command.

## Store suitability

Store suitability describes whether a store is appropriate for a given graft.

A store may be writable but still unsuitable for some workloads.

Examples:

```text
A POSIX filesystem may be suitable for executable development trees.

A host-shared removable filesystem may be suitable for documents but unsuitable for executable files.

A FUSE or network filesystem may be suitable for user data but unsuitable for critical package-manager state.
```

Suitability is determined by filesystem semantics, availability, durability, permissions, execution support, and the type of data being grafted.