# Configuration

StorageGraft configuration is organized around named stores.

The configuration model is holonic: the user configuration tree mirrors the system configuration tree. Each plane has its own main configuration file, store declarations, and path declarations.

## Configuration planes

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

The system plane defines system-wide defaults, system stores, system path declarations, and authoritative policy.

The user plane defines user-level defaults, user stores, and user path declarations, subject to system policy.

## System configuration layout

Recommended system layout:

```text
/etc/storagegraft/
├── storagegraft.conf
├── stores.d/
│   └── <store>.conf
└── paths.d/
    └── <store>.paths
```

## User configuration layout

Recommended user layout:

```text
/home/<user>/.storagegraft/
├── storagegraft.conf
├── stores.d/
│   └── <store>.conf
└── paths.d/
    └── <store>.paths
```

The user configuration directory is `.storagegraft`, not `.config/storagegraft`.

StorageGraft control files need to remain available before ordinary user data trees are grafted. Since `.config`, `.local`, `.cache`, and other user trees may themselves become graft candidates, StorageGraft keeps its user declaration plane outside those commonly grafted locations.

## Store names

Store names are the join keys that connect store configuration to path lists.

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

declares origin addresses for the store named:

```text
main
```

## Main configuration files

Main configuration files define defaults and policy for their configuration plane.

System main configuration:

```text
/etc/storagegraft/storagegraft.conf
```

User main configuration:

```text
/home/<user>/.storagegraft/storagegraft.conf
```

A main configuration file uses simple `key=value` syntax.

Example:

```text
default_activation=external
default_graft_mode=bind
default_migration=direct-verified
default_conflict=refuse
```

Blank lines are ignored.

Lines beginning with `#` are ignored.

## Store configuration files

Store configuration files live under `stores.d`.

System store declarations:

```text
/etc/storagegraft/stores.d/<store>.conf
```

User store declarations:

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

Blank lines are ignored.

Lines beginning with `#` are ignored.

## Store configuration keys

### `root`

Required.

The mount point of the store.

Example:

```text
root=/mnt/store
```

StorageGraft treats this directory as the store root.

For an origin address such as:

```text
/home/<user>/example
```

and a store root of:

```text
/mnt/store
```

the store subtree is:

```text
/mnt/store/home/<user>/example
```

### `activation`

Describes how the store becomes available.

Common values:

```text
auto
auto-late
external
noauto
disabled
```

`auto` means the store is expected to become available during normal system startup.

`auto-late` means the store may become available after normal startup and uses late-availability lifecycle handling.

`external` means StorageGraft does not mount the store. It only uses the store when it is already mounted.

`noauto` means the store is known to StorageGraft but activated only by explicit command.

`disabled` means the store is ignored.

### `managed`

Declares whether StorageGraft-managed lifecycle units control the store mount.

Common values:

```text
true
false
```

If `managed=true`, StorageGraft may use or generate systemd mount-related units for the store.

If `managed=false`, StorageGraft treats the store as externally mounted.

### `what`

The mount source for a managed store.

Examples:

```text
what=/path/to/store.img
what=UUID=00000000-0000-0000-0000-000000000000
what=server:/export/path
```

### `type`

The filesystem type for a managed store.

Examples:

```text
type=ext4
type=btrfs
type=nfs
type=cifs
```

### `options`

Mount options for a managed store.

Example:

```text
options=loop,rw,nofail
```

### `kind`

Describes the broad kind of store.

Examples:

```text
kind=filesystem
kind=loop-image
kind=block-device
kind=network-filesystem
kind=distributed-filesystem
kind=fuse
kind=pool
kind=shared-host
kind=unknown
```

### `semantics`

Describes expected filesystem behavior.

Examples:

```text
semantics=posix
semantics=limited-posix
semantics=shared-host
semantics=network
semantics=fuse
semantics=unknown
```

### `durability`

Describes the broad durability or risk class of the store.

Examples:

```text
durability=single
durability=single-removable
durability=local-redundant
durability=network-dependent
durability=cluster-defined
durability=backend-defined
durability=unknown
```

### `graft_mode`

Declares the graft mechanism.

Initial value:

```text
graft_mode=bind
```

### `migration`

Declares the migration strategy.

Initial value:

```text
migration=direct-verified
```

`direct-verified` means StorageGraft migrates or merges data directly into the final store subtree, verifies the result, clears origin contents after verification, and then activates the bind mount.

### `conflict`

Declares the conflict policy.

Initial value:

```text
conflict=refuse
```

`refuse` means StorageGraft does not automatically overwrite, replace, rename, or discard conflicting data.

### `users`

Declares whether user path declarations are accepted for this store.

Common values:

```text
allow
deny
```

### `user_scope`

Declares the default scope for user path declarations.

Initial value:

```text
user_scope=home-only
```

`home-only` means user-declared origin addresses resolve within the declaring user’s home directory.

## Path lists

Path lists live under `paths.d`.

System path lists:

```text
/etc/storagegraft/paths.d/<store>.paths
```

User path lists:

```text
/home/<user>/.storagegraft/paths.d/<store>.paths
```

A path list contains origin address entries, one per line.

Blank lines are ignored.

Lines beginning with `#` are ignored.

Example:

```text
# Example path list
projects
.cache/example
/home/<user>/example
```

## Relative path resolution

Path list entries may be absolute or relative.

StorageGraft validates the resolved origin address.

System path list entries resolve relative to:

```text
/
```

User path list entries resolve relative to the declaring user’s home directory.

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

After resolution, StorageGraft computes the store subtree:

```text
store subtree = store root + resolved origin address
```

Example:

```text
store root:
  /mnt/store

user path entry:
  example

declaring user home:
  /home/<user>

resolved origin address:
  /home/<user>/example

store subtree:
  /mnt/store/home/<user>/example
```

## System stores and system paths

A system store is declared under:

```text
/etc/storagegraft/stores.d/
```

A system path list is declared under:

```text
/etc/storagegraft/paths.d/
```

System declarations are root-owned policy.

A system store may serve system path declarations and user path declarations when policy allows it.

## User stores and user paths

A user store is declared under:

```text
/home/<user>/.storagegraft/stores.d/
```

A user path list is declared under:

```text
/home/<user>/.storagegraft/paths.d/
```

User declarations are requests, not authority.

A user store normally serves only that user’s allowed origin addresses.

By default, a user-declared store cannot graft system paths.

By default, a user-declared path resolves within that user’s home directory.

## Configuration composition

StorageGraft composes system and user configuration in this order:

```text
system main configuration
system store declarations
system path declarations
user main configuration
user store declarations
user path declarations
policy validation
planning
```

System policy remains authoritative.

User configuration may contribute stores, paths, and preferences within allowed policy.

User configuration cannot grant itself privileged authority.

## Example: system-managed store

Store configuration:

```text
/etc/storagegraft/stores.d/main.conf
```

Content:

```text
root=/mnt/store
activation=auto-late
managed=true
what=/path/to/store.img
type=ext4
options=loop,rw,nofail
kind=loop-image
semantics=posix
durability=single-removable
graft_mode=bind
migration=direct-verified
conflict=refuse
users=allow
user_scope=home-only
```

System path list:

```text
/etc/storagegraft/paths.d/main.paths
```

Content:

```text
usr/local
var/cache/apt/archives
```

User path list:

```text
/home/<user>/.storagegraft/paths.d/main.paths
```

Content:

```text
projects
.cache/example
```

## Example: externally mounted store

Store configuration:

```text
/etc/storagegraft/stores.d/shared.conf
```

Content:

```text
root=/mnt/shared
activation=external
managed=false
kind=network-filesystem
semantics=network
durability=backend-defined
graft_mode=bind
migration=direct-verified
conflict=refuse
users=allow
user_scope=home-only
```

## Example: user-declared store

User store configuration:

```text
/home/<user>/.storagegraft/stores.d/personal.conf
```

Content:

```text
root=/home/<user>/mnt/personal
activation=external
managed=false
kind=fuse
semantics=fuse
durability=backend-defined
graft_mode=bind
migration=direct-verified
conflict=refuse
users=allow
user_scope=home-only
```

User path list:

```text
/home/<user>/.storagegraft/paths.d/personal.paths
```

Content:

```text
Documents
Pictures
```

## File ownership

System configuration files are trusted only when owned by root and not writable by group or other users.

User configuration files are declarations only. They are accepted only when owned by the declaring user and not writable by group or other users.

## Design principle

StorageGraft configuration is self-similar across system and user planes.

Each plane has:

```text
storagegraft.conf
stores.d/
paths.d/
```

The system plane governs policy.

The user plane contributes declarations.

The reconciler composes both into a storage-graft plan.