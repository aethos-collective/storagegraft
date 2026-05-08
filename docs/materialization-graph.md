# Materialization Graph

StorageGraft manages two related graphs:

```text
store materialization graph
graft exposure graph
```

The store materialization graph describes how a usable store becomes available.

The graft exposure graph describes how selected store subtrees are exposed back at their origin addresses.

These graphs are related, but they are not the same graph.

## Store materialization graph

A store is not always primitive.

A store may depend on another storage layer before its own root can be mounted and used.

Example:

```text
ChromeOS shared SD-card export
→ disk-image backing file
→ loop device
→ ext4 filesystem
→ mounted store root
```

In this example, the mounted store root exists only after every earlier layer has become available.

The usable store is:

```text
/mnt/extra-disk
```

but it depends on:

```text
/mnt/chromeos/shared/removable/sdcard/.crostini/extra-disk.img
```

which depends on the ChromeOS shared SD-card export.

## Backend chain

A backend chain is the ordered dependency chain that makes a store root possible.

Example backend chain:

```text
/mnt/chromeos/shared/removable/sdcard
→ /mnt/chromeos/shared/removable/sdcard/.crostini/extra-disk.img
→ /dev/loop0
→ /mnt/extra-disk
```

Each layer depends on the layer before it.

If an earlier layer fails, later layers may fail even if they still appear mounted.

## Store root

A store root is the mounted filesystem root used by StorageGraft for grafting.

Example:

```text
/mnt/extra-disk
```

StorageGraft computes store subtrees from the store root and resolved origin addresses:

```text
store subtree = store root + resolved origin address
```

Example:

```text
store root:
  /mnt/extra-disk

resolved origin address:
  /home/chris/.gnupg

store subtree:
  /mnt/extra-disk/home/chris/.gnupg
```

## Graft exposure graph

The graft exposure graph describes bind-mount exposure.

Example:

```text
/mnt/extra-disk/home/chris/.gnupg
→ /home/chris/.gnupg
```

The store subtree is the backing data location.

The origin address is the visible location applications use.

The exposure mechanism is a bind mount:

```text
mount --bind /mnt/extra-disk/home/chris/.gnupg /home/chris/.gnupg
```

## Complete chain

A full live StorageGraft chain may include both graphs:

```text
ChromeOS shared SD-card export
→ disk-image backing file
→ loop device
→ ext4 filesystem
→ mounted store root
→ store subtree
→ bind-mounted origin address
```

Concrete example:

```text
/mnt/chromeos/shared/removable/sdcard
→ /mnt/chromeos/shared/removable/sdcard/.crostini/extra-disk.img
→ /dev/loop0
→ /mnt/extra-disk
→ /mnt/extra-disk/home/chris/.gnupg
→ /home/chris/.gnupg
```

The first part is materialization.

The final part is graft exposure.

## Dependency ordering

StorageGraft must respect dependency order.

Activation order:

```text
1. backing substrate available
2. backing object available
3. store filesystem mounted
4. store subtree available
5. origin address validated
6. migration or merge completed when required
7. bind graft activated
```

Unmount order is the reverse:

```text
1. bind graft unmounted
2. store filesystem unmounted
3. loop device released when applicable
4. backing object released when applicable
5. backing substrate released when applicable
```

A graft must not be activated before its store root is available.

A store must not be unmounted while grafts depending on it are still active.

## Nested stores

Nested stores are allowed.

A store may depend on another store, another mount, a disk image, a loop device, a network filesystem, a host-shared filesystem, a FUSE mount, or another storage substrate.

StorageGraft must not assume that every store is directly backed by a physical disk.

Examples:

```text
disk image on removable storage
disk image on a network share
filesystem inside a loop device
filesystem inside an encrypted volume
FUSE mount backed by remote storage
pooled filesystem backed by multiple devices
```

## Failure propagation

Failures propagate through the materialization graph.

If a lower layer fails, upper layers may report errors.

Example:

```text
ChromeOS shared SD-card export becomes read-only
→ disk-image writes fail
→ loop device receives I/O errors
→ ext4 journal aborts
→ mounted store remounts read-only
→ grafted origins become unsafe for writes
```

StorageGraft must treat this as a store materialization failure, not merely as a graft failure.

## Store suitability and materialization

Store suitability depends on the full backend chain, not only the final filesystem type.

A store root may be ext4 and still depend on a fragile backing layer.

Example:

```text
store root:
  /mnt/extra-disk

filesystem:
  ext4

backend:
  disk image on ChromeOS shared SD-card 9p export
```

The final filesystem has POSIX semantics, but its durability and write reliability are constrained by the backend chain.

StorageGraft therefore distinguishes:

```text
filesystem semantics:
  what the mounted store can represent

backend durability:
  how reliable the backing chain is

activation mode:
  how and when the store becomes available

graft suitability:
  whether a specific origin address should use that store
```

## Already-grafted state

A graft is already satisfied when the origin address is a mount point and the origin address refers to the same filesystem object as the expected store subtree.

Example:

```text
origin address:
  /home/chris/.gnupg

expected store subtree:
  /mnt/extra-disk/home/chris/.gnupg
```

If these paths refer to the same object, the graft is already active.

Planner result:

```text
action: none
policy: already-grafted
```

If the origin address is a mount point but does not refer to the expected store subtree, StorageGraft refuses the graft.

Planner result:

```text
action: refused
policy: unrelated-mount
```

## Prototype units

Existing prototype systemd units may be used during development when they already materialize a store.

Example prototype units:

```text
mnt-extra\x2ddisk.mount
root-graft-extra-disk.path
root-graft-extra-disk.timer
```

These units are operational precursors, not canonical StorageGraft names.

StorageGraft-native lifecycle material should eventually replace prototype units with names and behavior derived from StorageGraft configuration.

## Design rule

StorageGraft must model both layers:

```text
how storage becomes available
how storage is exposed
```

It must not collapse backend materialization and bind-graft exposure into one concept.

The store materialization graph answers:

```text
What has to exist before the store root is usable?
```

The graft exposure graph answers:

```text
What store subtree appears at what origin address?
```