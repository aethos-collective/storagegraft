# systemd Model

StorageGraft is systemd-native.

systemd owns lifecycle, activation, ordering, retry behavior, and unit state wherever possible. StorageGraft supplies configuration, planning, validation, migration policy, merge policy, reconciliation behavior, and generated unit material when needed.

StorageGraft does not duplicate systemd’s role as the system and service manager.

## Responsibilities

systemd owns:

```text
service activation
mount activation
path-based activation
timer-based retry
dependency ordering
unit state
restart behavior
boot integration
shutdown ordering
```

StorageGraft owns:

```text
store declarations
path declarations
planning
validation
migration policy
merge policy
conflict detection
bind-graft reconciliation
status reporting
unit generation when needed
```

## Store lifecycle

A store may be managed or unmanaged.

A managed store is brought online through StorageGraft-managed systemd configuration.

An unmanaged store is mounted by something outside StorageGraft. StorageGraft consumes it only when it is already mounted and suitable for the requested grafts.

## Managed stores

A managed store may use systemd units such as:

```text
.mount
.path
.timer
.automount
.service
```

The exact unit set depends on the store’s activation mode.

Managed store configuration uses StorageGraft’s simple `key=value` store format.

Example:

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

## Unmanaged stores

An unmanaged store has:

```text
managed=false
```

StorageGraft does not create mount units for unmanaged stores.

It checks whether the store root is mounted and whether it is suitable for the declared grafts.

Example unmanaged store configuration:

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

## Mount units

A `.mount` unit represents a mount point.

For managed stores, StorageGraft may provide or generate a `.mount` unit.

Mount units are named according to the mount point they control.

Example:

```text
mount point:
  /mnt/store

mount unit:
  mnt-store.mount
```

For mount points containing characters that systemd escapes, the correct unit name is obtained with:

```text
systemd-escape -p --suffix=mount /path/to/mountpoint
```

StorageGraft store names do not replace systemd mount-unit naming.

## Path units

A `.path` unit can trigger another unit when a path appears or changes.

StorageGraft uses `.path` units for late-available stores.

Examples of late-available stores include:

```text
removable media
host-shared paths
disk images on removable media
network-dependent mount sources
user-session-provided store roots
```

A `.path` unit is useful when the mount source may not exist at normal startup time.

## Timer units

A `.timer` unit can retry activation or reconciliation.

StorageGraft uses `.timer` units as a fallback when path activation is not enough.

Timer units are useful for:

```text
late store availability
missed path events
retrying failed mount attempts
periodic reconciliation
```

## Automount units

An `.automount` unit can activate a mount when its mount point is accessed.

StorageGraft may use automount behavior when lazy activation is preferable to eager startup.

Automounts are not a replacement for migration planning. A graft still requires planning and validation before data movement or bind activation.

## Reconcile services

StorageGraft reconciliation may be invoked by a systemd service.

A reconcile service runs a bounded command such as:

```text
storagegraft reconcile
```

The service does not normally remain resident forever.

systemd is the resident lifecycle manager. StorageGraft performs reconciliation passes.

## Activation modes

StorageGraft store configurations use activation modes.

Supported activation values:

```text
auto
auto-late
external
noauto
disabled
```

## `auto`

The store is expected to become available during normal system startup.

A managed `auto` store may be represented by a normal `.mount` unit enabled into the appropriate target.

## `auto-late`

The store may become available after normal startup.

A managed `auto-late` store uses late-availability mechanisms such as:

```text
.mount
.path
.timer
```

The `.mount` unit defines the mount.

The `.path` unit triggers the mount when the mount source appears.

The `.timer` unit retries if timing races occur.

## `external`

The store is mounted by something outside StorageGraft.

StorageGraft does not attempt to mount it.

Reconciliation proceeds only when the store root is mounted.

## `noauto`

The store is known to StorageGraft but is not automatically mounted or reconciled during normal startup.

It may be activated explicitly by a command such as:

```text
storagegraft mount <store>
storagegraft reconcile <store>
```

## `disabled`

The store is ignored.

StorageGraft does not mount, reconcile, or process path lists for a disabled store.

## Bind graft lifecycle

A bind graft may be activated directly by StorageGraft or represented by generated systemd mount units.

The basic bind operation is:

```text
mount --bind <store subtree> <origin address>
```

Generated bind mount units depend on the store mount.

For a store mounted by:

```text
mnt-store.mount
```

a bind graft unit is ordered after that store mount.

Common dependency pattern:

```ini
Requires=mnt-store.mount
After=mnt-store.mount
```

StorageGraft ensures that migration or merge verification occurs before bind activation.

## Ordering

Store mounts must be active before grafts that depend on them.

Grafts are activated only after:

```text
store root is mounted
origin address is validated
store subtree is validated
migration or merge is complete when required
```

Nested grafts require careful ordering.

When activating nested grafts, deeper origin addresses are generally handled before broader parent grafts if both are explicitly declared.

When unmounting nested grafts, deeper grafts are unmounted before their parents.

## Late-available disk-image pattern

A common managed-store pattern is a disk image that appears after startup.

The systemd model is:

```text
.mount:
  defines the mount point and loop mount

.path:
  watches for the disk image path

.timer:
  retries activation

.service:
  optionally runs StorageGraft reconciliation after the store is mounted
```

The `.mount` unit is not enabled directly into normal startup when the mount source is expected to be absent at that time.

Instead, `.path` and `.timer` units trigger it when the source becomes available.

## Example mount unit

This is a systemd unit file, so it uses systemd’s native INI-style unit syntax.

```ini
[Unit]
Description=Mount store image at /mnt/store
After=local-fs.target
ConditionPathExists=/path/to/store.img

[Mount]
What=/path/to/store.img
Where=/mnt/store
Type=ext4
Options=loop,rw,nofail
```

## Example path unit

This is a systemd unit file, so it uses systemd’s native INI-style unit syntax.

```ini
[Unit]
Description=Watch for store image

[Path]
PathExists=/path/to/store.img
Unit=mnt-store.mount

[Install]
WantedBy=multi-user.target
```

## Example timer unit

This is a systemd unit file, so it uses systemd’s native INI-style unit syntax.

```ini
[Unit]
Description=Retry mounting store

[Timer]
OnBootSec=10s
OnUnitActiveSec=15s
AccuracySec=5s
Unit=mnt-store.mount

[Install]
WantedBy=timers.target
```

## Reconciliation trigger

After a store is mounted, StorageGraft may run reconciliation.

This may be done by:

```text
a service ordered after the store mount
a timer-triggered reconcile service
a path-triggered reconcile service
a manual storagegraft reconcile command
```

A reconcile service is idempotent.

Repeated runs do not duplicate mounts, overwrite data, or restart completed migrations unnecessarily.

## Generated units

StorageGraft may generate units for managed stores and bind grafts.

Generated units remain inspectable.

Generated unit names follow systemd naming rules.

Generated unit contents are derived from store configuration and graft plans.

StorageGraft does not hide generated lifecycle state from administrators.

## Direct mode

StorageGraft may also support direct mode, where it performs mount or bind operations directly during reconciliation.

Direct mode is useful for:

```text
early implementation
manual testing
systems where generated units are not desired
temporary operations
```

Direct mode follows the same planning, validation, migration, and idempotency rules.

## Shutdown and unmounting

Grafts using a store are unmounted before the store itself is unmounted.

Unmount ordering accounts for nested grafts.

Unmounting a graft does not delete data from the store subtree.

Unmounting a store does not delete the store.

StorageGraft distinguishes:

```text
unmount graft
unmount store
disable store
remove configuration
delete data
```

These are different operations.

## Failure behavior

If a store mount fails, StorageGraft reports the store as unavailable and does not graft paths into it.

If reconciliation fails, StorageGraft leaves already-safe data in place and reports the failure.

If a bind graft fails after migration, StorageGraft reports that data has been moved but the graft is not active.

If a store disappears, StorageGraft does not assume the data is gone. It reports the store as unavailable.

## Current implementation boundary

The current POSIX shell implementation is non-mutating.

Implemented commands:

```text
storagegraft check
storagegraft status [store]
storagegraft plan [store]
```

The current implementation inspects configuration, stores, path lists, mounted state, origin state, and store subtree state.

It does not mount stores.

It does not migrate data.

It does not merge data.

It does not clear origin contents.

It does not activate bind mounts.

It does not generate systemd units.

Managed lifecycle behavior belongs to later implementation phases after planning, validation, and conflict detection are reliable.

## Design principle

StorageGraft extends systemd’s mount lifecycle with storage-graft policy.

It does not replace systemd’s lifecycle model.

The intended relationship is:

```text
systemd:
  activation, ordering, retry, unit state

mount:
  filesystem attachment

bind mount:
  namespace exposure

StorageGraft:
  declaration, planning, migration, validation, reconciliation
```