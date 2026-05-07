# Store Suitability

A mounted store is not automatically suitable for every graft.

StorageGraft treats store suitability as a first-class concern. A store may be mounted, writable, and available, yet still be a poor target for certain origin addresses.

Suitability depends on filesystem semantics, permissions, execution support, durability, latency, availability, and the kind of data being grafted.

## Principle

StorageGraft does not treat all mounted filesystems as equivalent.

A store is evaluated before it is used for a graft.

Examples:

```text
A local POSIX filesystem may be suitable for executable development trees.

A host-shared removable filesystem may be suitable for documents but unsuitable for executable files.

A FUSE or network filesystem may be suitable for user data but unsuitable for package-manager state.

A removable single-device store may be suitable for caches but unsuitable for critical system state.
```

## Store properties

A store configuration may describe store properties.

Store configuration files use StorageGraft’s simple `key=value` syntax.

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

These fields help StorageGraft plan, warn, or refuse grafts.

## `kind`

The `kind` property describes the broad storage kind.

Common values:

```text
filesystem
loop-image
block-device
network-filesystem
distributed-filesystem
fuse
pool
shared-host
unknown
```

Examples:

```text
kind=loop-image
kind=network-filesystem
kind=fuse
kind=pool
```

## `semantics`

The `semantics` property describes expected filesystem behavior.

Common values:

```text
posix
limited-posix
shared-host
network
fuse
unknown
```

A `posix` store is generally expected to support ordinary Linux filesystem semantics.

A `limited-posix` store may support some Linux operations but not all of them.

A `shared-host` store is exposed through a host-sharing mechanism and may not support execution, ownership, permissions, symlinks, or metadata exactly like a native Linux filesystem.

A `network` store may have latency, availability, locking, or consistency concerns.

A `fuse` store is implemented through a user-space filesystem and may vary widely in behavior.

An `unknown` store is treated conservatively.

## `durability`

The `durability` property describes the broad risk class of the store.

Common values:

```text
single
single-removable
local-redundant
network-dependent
cluster-defined
backend-defined
unknown
```

A `single` store has no known redundancy.

A `single-removable` store is a single removable storage device or image.

A `local-redundant` store is backed by local redundancy such as RAID, mirrored ZFS, or another redundant local storage configuration.

A `network-dependent` store depends on network availability.

A `cluster-defined` store depends on cluster-level storage policy.

A `backend-defined` store has durability controlled by the underlying storage backend.

An `unknown` store is treated conservatively.

## `scope`

The `scope` property describes how the store is expected to be used.

Common values:

```text
system
user
shared
```

A `system` store is available at the system level.

A `user` store is associated with a user session or user-owned mount.

A `shared` store may be used by more than one user.

## Suitability checks

StorageGraft may check whether a store supports:

```text
read access
write access
execute permission
ownership preservation
permission preservation
timestamps
symlinks
hard links
extended attributes
file locking
atomic rename
fsync behavior
sparse files
stable availability
```

Not all checks are required for all grafts.

The required checks depend on the origin address and path class.

## Path classes

StorageGraft may classify origin addresses by expected use.

Common path classes include:

```text
user-data
user-cache
user-config
development-tree
local-admin
package-cache
logs
spool
application-state
critical-system-state
pseudo-runtime
```

## User data

Examples:

```text
/home/<user>/Documents
/home/<user>/Pictures
/home/<user>/Videos
/home/<user>/Music
```

User data may be suitable for many store types, including removable, network, and FUSE-backed stores, depending on performance and reliability expectations.

## User cache

Examples:

```text
/home/<user>/.cache
/home/<user>/.npm
/home/<user>/.cache/pip
```

User cache data is often regenerable.

It may be suitable for removable stores or lower-durability stores, provided the user accepts the risk.

## User configuration

Examples:

```text
/home/<user>/.config
/home/<user>/.local/state
```

User configuration may be important for application behavior.

StorageGraft treats user configuration more cautiously than ordinary documents or cache data.

StorageGraft’s own user configuration lives under:

```text
/home/<user>/.storagegraft/
```

This avoids placing StorageGraft’s control plane under commonly grafted user configuration trees.

## Development trees

Examples:

```text
/home/<user>/projects
/home/<user>/src
/home/<user>/work
```

Development trees often require:

```text
executable files
symlinks
chmod
timestamps
Git metadata
build tool compatibility
case-sensitive paths
stable permissions
```

A POSIX-capable store is strongly preferred.

Host-shared removable filesystems and some FUSE/network stores may be unsuitable.

## Local administrator trees

Examples:

```text
/usr/local
/opt
```

These paths often contain locally installed software, scripts, binaries, libraries, and administrator-managed tools.

They generally require POSIX permissions and executable support.

A POSIX-capable store is strongly preferred.

## Package cache

Examples:

```text
/var/cache/apt/archives
/var/cache/example
```

Package caches can grow large and are often regenerable.

They are good candidates for grafting, provided the store is available when package operations run.

## Logs

Examples:

```text
/var/log
```

Logs can grow over time and may become candidates for grafting.

StorageGraft treats logs carefully because logging may start early and services may expect the log path to be available.

Store availability and service ordering matter.

## Spool data

Examples:

```text
/var/spool
/var/spool/example
```

Spool directories may contain queued work.

Suitability depends on the service using the spool.

StorageGraft treats spool paths as service-sensitive.

## Application state

Examples:

```text
/var/lib/example
/home/<user>/.local/share/example
```

Application state may be critical, regenerable, or somewhere in between.

Suitability depends on the specific application.

StorageGraft does not assume all application state is safe to graft into every store.

## Critical system state

Examples:

```text
/var/lib/dpkg
/var/lib/systemd
/etc
/boot
```

Critical system state is denied or heavily restricted by default.

If a store is missing, late, slow, removable, or semantically weak, grafting critical system state can make the system difficult to repair.

## Pseudo-runtime paths

Examples:

```text
/dev
/proc
/sys
/run
```

Pseudo-runtime paths are not ordinary storage targets.

StorageGraft rejects them.

## System store suitability

A system store is declared under:

```text
/etc/storagegraft/stores.d/
```

A system store may serve system path declarations and user path declarations when policy allows it.

System stores are suitable for broader use only when their backing storage, availability, permissions, and durability support the requested grafts.

## User store suitability

A user store is declared under:

```text
/home/<user>/.storagegraft/stores.d/
```

A user store is a user-owned declaration.

A user store normally serves only that user’s allowed origin addresses.

By default, a user-declared store does not graft system paths.

User stores may be appropriate for user data, user caches, selected development work, or user-session storage, depending on the store’s semantics.

## Suggested default policy

A conservative default policy may look like this:

```text
POSIX local store:
  allow user-data
  allow user-cache
  allow development-tree
  allow local-admin
  allow package-cache
  warn logs
  warn application-state
  deny critical-system-state
  deny pseudo-runtime

single removable POSIX store:
  allow user-data
  allow user-cache
  allow development-tree
  allow local-admin with warning
  allow package-cache
  warn logs
  warn application-state
  deny critical-system-state
  deny pseudo-runtime

host-shared store:
  allow user-data
  allow some user-cache
  warn user-config
  deny development-tree unless execution and POSIX semantics are proven
  deny local-admin
  deny critical-system-state
  deny pseudo-runtime

FUSE or network store:
  allow user-data with warning
  allow selected user-cache with warning
  warn development-tree
  deny local-admin by default
  deny package-manager-critical state
  deny critical-system-state
  deny pseudo-runtime
```

## Store absence

Suitability includes availability.

A store that is sometimes absent may still be useful, but not for every graft.

Removable, network, user-session, and distributed stores are treated as potentially absent.

StorageGraft reports store absence clearly and avoids destructive assumptions.

## Store degradation

Some stores can be degraded or partially available.

Examples:

```text
RAID array with missing member
cluster filesystem with degraded redundancy
network filesystem with stale mount
FUSE daemon not responding
removable media intermittently failing
```

StorageGraft reports degraded store state when it can detect it.

StorageGraft does not treat degraded state as equivalent to healthy state.

## Store suitability output

Status output should make store suitability visible.

Example:

```text
STORE        ROOT        KIND         STATE     SUITABILITY
main         /mnt/store  filesystem   mounted   posix
media        /mnt/media  shared-host  mounted   noexec-likely
mesh         /mnt/mesh   fuse         mounted   network/fuse warning
```

Graft plans should also show suitability decisions.

Example:

```text
ORIGIN ADDRESS              STORE   CLASS             POLICY
/home/<user>/example        main    development-tree  allow
/usr/local                  media   local-admin       deny-noexec
/var/cache/apt/archives     main    package-cache     allow
/var/lib/dpkg               mesh    critical-system   deny
```

## Current implementation boundary

The current POSIX shell implementation records and reports basic store properties.

Implemented commands:

```text
storagegraft check
storagegraft status [store]
storagegraft plan [store]
```

The current implementation reports configured values such as:

```text
kind
semantics
durability
```

It does not yet enforce a complete suitability policy.

Suitability enforcement belongs to later implementation phases after planning, validation, and conflict detection are reliable.

## Design rule

Mounted does not mean suitable.

Writable does not mean safe.

StorageGraft uses store suitability to decide whether to allow, warn, or refuse a graft.