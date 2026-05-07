# Security Model

StorageGraft changes the filesystem namespace by moving data and activating bind mounts.

That makes it powerful enough to cause data loss, hide data, expose data through unexpected paths, or turn user-controlled declarations into privileged filesystem actions if it is not careful.

This document defines StorageGraft’s security model.

## Trust boundaries

StorageGraft has three major trust boundaries:

```text
system configuration
user configuration
mounted stores
```

Each boundary has different authority.

System configuration is root-owned policy.

User configuration is user-owned declaration.

Mounted stores are storage substrates that must be inspected before use.

## System configuration

System configuration lives under:

```text
/etc/storagegraft/
```

System configuration layout:

```text
/etc/storagegraft/
├── storagegraft.conf
├── stores.d/
│   └── <store>.conf
└── paths.d/
    └── <store>.paths
```

System configuration is trusted only when it is owned by root and not writable by group or other users.

System configuration includes:

```text
/etc/storagegraft/storagegraft.conf
/etc/storagegraft/stores.d/<store>.conf
/etc/storagegraft/paths.d/<store>.paths
```

StorageGraft rejects unsafe system configuration files.

A system configuration file is unsafe when:

```text
it is not owned by root
it is writable by group or other users
it is a symlink where a regular file is required
its parent directory is writable by untrusted users
```

## User configuration

User configuration lives under:

```text
/home/<user>/.storagegraft/
```

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

User configuration includes:

```text
/home/<user>/.storagegraft/storagegraft.conf
/home/<user>/.storagegraft/stores.d/<store>.conf
/home/<user>/.storagegraft/paths.d/<store>.paths
```

A user configuration file is acceptable only when:

```text
it is owned by the declaring user
it is not writable by group or other users
it is not a symlink where a regular file is required
it is a regular file
it resides under the declaring user’s .storagegraft tree
```

The system reconciler validates user configuration before acting on it.

## User stores

A user store is declared under:

```text
/home/<user>/.storagegraft/stores.d/
```

A user store is a declaration, not privileged authority.

A user-declared store normally serves only that user’s allowed origin addresses.

By default, a user-declared store cannot graft system paths.

By default, a user-declared store cannot graft another user’s home directory.

A user-declared store must remain within allowed policy before StorageGraft uses it for a graft.

## User path declarations

A user path list lives under:

```text
/home/<user>/.storagegraft/paths.d/<store>.paths
```

A user path list contains origin address entries.

Path-list entries may be absolute or relative.

StorageGraft validates the resolved origin address, not merely the text of the entry.

For user path lists, relative entries resolve against the declaring user’s home directory.

Example:

```text
entry:
  example

declaring user home:
  /home/<user>

resolved origin address:
  /home/<user>/example
```

Under the default `home-only` scope, a user-declared origin address must resolve within the declaring user’s home directory.

Under `home-only`, StorageGraft rejects a user declaration when the resolved origin address:

```text
is the home directory itself
is outside the declaring user’s home directory
is under a pseudo-runtime path
is inside the store root for the same store
is an unrelated active mount point
resolves through unsafe symlink structures
```

## System path declarations

A system path list lives under:

```text
/etc/storagegraft/paths.d/<store>.paths
```

A system path list contains origin address entries.

Path-list entries may be absolute or relative.

For system path lists, relative entries resolve against:

```text
/
```

Example:

```text
entry:
  usr/local

resolved origin address:
  /usr/local
```

System path declarations are root-owned policy.

## Mounted stores

A mounted store is not automatically trusted.

A store may be writable but unsuitable for a given graft.

StorageGraft classifies stores by suitability, including:

```text
filesystem type
local or remote
kernel filesystem or FUSE
POSIX capability
ownership behavior
permission behavior
execution support
durability
availability
latency
removability
redundancy
```

Examples:

```text
A local POSIX filesystem may be suitable for executable development trees.

A host-shared removable filesystem may be suitable for documents but unsuitable for executable files.

A network or FUSE filesystem may be suitable for user data but unsuitable for package-manager state.

A removable single-device store may be unsuitable for critical system state.
```

Mounted does not mean suitable.

Writable does not mean safe.

## Origin address validation

Before acting on an origin address, StorageGraft validates the resolved origin address.

A resolved origin address must:

```text
be normalized
not be /
not be a pseudo-runtime path
not be inside the store root for the same store
not escape the allowed user scope
not resolve through unsafe symlink structures
```

StorageGraft rejects resolved origin addresses under:

```text
/dev
/proc
/sys
/run
```

StorageGraft rejects or heavily restricts boot-critical and package-manager-critical paths unless explicit root-owned policy allows them.

Dangerous paths include:

```text
/
/boot
/etc
/bin
/sbin
/lib
/lib64
/usr/bin
/usr/sbin
/usr/lib
/var/lib/dpkg
/var/lib/systemd
```

## Store subtree validation

For each resolved origin address, StorageGraft computes:

```text
store subtree = store root + resolved origin address
```

Before migration or bind activation, StorageGraft validates the store subtree.

The store subtree must:

```text
remain under the store root
not resolve outside the store root
not be an unsafe symlink
not be an unrelated active mount point
be a directory when it exists
```

The store subtree is the physical storage location for the graft.

## Symlink handling

Symlinks are a security boundary.

StorageGraft avoids following untrusted symlinks when deciding where to migrate, merge, clean, or bind.

Dangerous cases include:

```text
origin address is a symlink
store subtree is a symlink
parent path redirects outside the allowed scope
user-declared path escapes through a symlink
store subtree escapes the store root through a symlink
```

When StorageGraft cannot prove that an operation stays inside the intended boundary, it refuses the operation.

## Mount point handling

StorageGraft distinguishes ordinary directories from mount points.

Before binding over an origin address, StorageGraft checks whether the origin address is already a mount point.

If the origin address is already mounted by StorageGraft and points to the expected store subtree, the operation is already satisfied.

If the origin address is an unrelated mount point, StorageGraft refuses the graft.

StorageGraft does not hide unrelated mounted filesystems.

## Data hiding risk

A bind mount can hide existing origin contents.

For that reason, StorageGraft does not bind over a non-empty origin address until data has been migrated or merged and verified.

If a bind mount is active, hidden origin contents may still exist underneath the mount.

Status output reports this condition when detected.

## Migration safety

StorageGraft migration is conservative.

Before cleanup, StorageGraft verifies that copied or merged data exists in the store subtree.

StorageGraft does not remove origin contents unless verification succeeds.

StorageGraft does not automatically overwrite, replace, rename, or discard conflicting data.

StorageGraft does not automatically merge when conflicts exist.

## Merge safety

An automatic merge is additive only.

StorageGraft may copy entries from the origin into the store subtree when those entries do not already exist at the same relative address.

StorageGraft refuses automatic merge when the same relative address exists on both sides and cannot be combined without changing or replacing an existing object.

Conflict examples:

```text
same relative file exists on both sides
file exists on one side and directory exists on the other
regular file exists on one side and symlink exists on the other
filesystem object type mismatch
unsupported special file collision
```

Directories with the same relative address are not conflicts by themselves. StorageGraft recurses into them and evaluates their contents.

## Cleanup safety

After migration or merge verification, StorageGraft clears contents inside the origin directory.

The origin directory itself remains in place as the mount point.

StorageGraft does not remove the origin directory itself during normal graft activation.

StorageGraft does not clean outside the origin address.

StorageGraft does not clean through unsafe symlinks.

## User path authority

A user-writable path list must not become root authority.

A user may declare requested grafts only within permitted scope.

The system reconciler decides whether the declaration is accepted.

User declarations cannot request grafts for:

```text
other users’ home directories
system directories
pseudo-filesystems
runtime directories
the store root itself
```

unless explicit root-owned policy allows it.

## Privilege model

StorageGraft requires privileged operations for:

```text
mounting stores
activating bind mounts
migrating system paths
clearing system path contents
generating systemd units
```

User declarations may be unprivileged, but applying them is privileged.

The privileged reconciler treats user-controlled input as untrusted.

## File ownership

System configuration files are trusted only when owned by root and not writable by group or other users.

User configuration files are accepted only when owned by the declaring user and not writable by group or other users.

StorageGraft rejects configuration files when ownership or permissions are unsafe.

## Concurrency

StorageGraft prevents concurrent reconciliation of the same store or graft set.

Concurrent operations can create duplicate mounts, inconsistent migration state, or unsafe cleanup.

StorageGraft uses locking around:

```text
store reconciliation
migration
merge
cleanup
bind activation
unmount operations
```

## Idempotency

StorageGraft operations are safe to retry.

A repeated reconciliation does not:

```text
duplicate copied data
overwrite existing data
create duplicate bind mounts
delete data unexpectedly
hide data unexpectedly
```

StorageGraft recognizes already-satisfied states and performs no action.

## Store absence

Stores may be late-available or temporarily absent.

When a store is absent, StorageGraft does not remove origin data, clear mount points, or assume data loss.

It reports the store as unavailable and retries according to lifecycle policy.

## Unmount behavior

Unmounting a graft removes the bind mount but does not delete data from the store subtree.

Unmounting a store happens only after grafts using that store are unmounted.

Unmount ordering accounts for nested grafts.

StorageGraft distinguishes:

```text
unmount graft
unmount store
disable store
remove configuration
delete data
```

These are different operations.

## Logging and status

StorageGraft reports security-relevant conditions clearly.

Examples:

```text
unsafe system configuration
unsafe user configuration
unsafe user declaration
store missing
store unsuitable
origin non-empty
store subtree non-empty
conflict detected
migration required
merge required
bind active
hidden origin content possible
unrelated mount point detected
```

The status command makes the current storage and graft state legible without guessing.

## Current implementation boundary

The current POSIX shell implementation is non-mutating.

Implemented commands:

```text
storagegraft check
storagegraft status [store]
storagegraft plan [store]
```

The current implementation inspects configuration, stores, path lists, mounted state, origin state, and store subtree state.

It does not migrate data.

It does not merge data.

It does not clear origin contents.

It does not activate bind mounts.

It does not generate systemd units.

Mutation behavior belongs to later implementation phases after planning, validation, and conflict detection are reliable.

## Default posture

StorageGraft is conservative by default.

When state is ambiguous, StorageGraft plans, reports, warns, or refuses rather than guessing.

The default security posture is:

```text
do not overwrite
do not hide data before migration
do not trust user declarations as authority
do not graft unsafe paths
do not assume all stores are equivalent
do not continue after ambiguous state
```