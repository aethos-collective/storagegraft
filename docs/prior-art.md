# Prior Art

StorageGraft is built around existing Linux storage, filesystem, mount, and service-management mechanisms.

This document records the main prior art that informs the project. StorageGraft is intended to compose these mechanisms, not replace them.

## Core Linux mount primitives

### `mount`

`mount` attaches a filesystem to the Linux directory tree.

StorageGraft relies on mounted filesystems as stores. A store may already be mounted by the administrator, or it may be mounted through StorageGraft-managed systemd configuration.

### Bind mounts

Bind mounts make an existing directory tree visible at another location.

StorageGraft uses bind mounts as its primary graft mechanism.

Example:

```text
mount --bind /mnt/store/home/<user>/example /home/<user>/example
```

In this example, the data lives under the store subtree, while applications continue to use the origin address.

### Recursive bind mounts

Recursive bind mounts extend bind-mount behavior to nested mounts.

StorageGraft should treat recursive bind mounts as an advanced feature. The default graft operation is an ordinary bind mount unless recursive behavior is explicitly needed.

### `/etc/fstab`

`/etc/fstab` is the traditional declarative mount table for Linux systems.

StorageGraft should remain compatible with the general idea of declarative mount configuration, while using systemd-native units where appropriate.

### `findmnt`

`findmnt` reports current mount state.

StorageGraft should use mount-state inspection rather than assuming that a path is or is not mounted based only on directory existence.

## systemd mount lifecycle

### `systemd.mount`

systemd mount units represent mounted filesystems.

StorageGraft should use native `.mount` units where systemd is responsible for mount lifecycle.

Mount units are named according to the mount point they control. Store names do not replace systemd mount-unit naming.

### `systemd.path`

systemd path units trigger units when paths appear or change.

StorageGraft can use `.path` units for stores that are late-available, such as removable media, shared host paths, or disk images that appear after startup.

### `systemd.timer`

systemd timer units provide retry and periodic activation.

StorageGraft can use `.timer` units to retry reconciliation when a store is not immediately available.

### `systemd.automount`

systemd automount units can mount filesystems on demand when their mount points are accessed.

StorageGraft may use automount behavior where lazy activation is preferable to eager startup.

### `systemd-fstab-generator`

`systemd-fstab-generator` translates `/etc/fstab` entries into native systemd mount units.

This is an important design precedent: declarative mount configuration can be compiled into systemd units.

### `systemd-mount`

`systemd-mount` creates transient mount or automount units.

StorageGraft may use transient units for some workflows, but persistent store definitions should remain inspectable through normal configuration files.

## Disk images and loop devices

### Disk images

A disk image is a regular file used as disk-like storage.

StorageGraft may use disk images as store backends, especially when the larger storage substrate is available as a file rather than as a block device.

### Loop devices

Loop devices expose regular files as block devices.

Loop devices are central to disk-image-backed stores, but they are not the whole StorageGraft model. A store does not have to be loop-backed.

### `mount -o loop`

`mount -o loop` mounts a filesystem image through an automatically associated loop device.

This is the preferred simple mechanism for disk-image stores when it works reliably.

### `losetup`

`losetup` explicitly associates disk images with loop devices.

StorageGraft may use `losetup` when it needs explicit loop-device control, inspection, or reuse detection.

When explicit loop setup is used, duplicate loop-device associations for the same disk image must be avoided.

### `systemd-loop@.service`

`systemd-loop@.service` is systemd prior art for attaching disk images as loop devices.

StorageGraft should learn from this where available, rather than inventing unnecessary loop-device lifecycle machinery.

### `systemd-dissect`

`systemd-dissect` can inspect, attach, mount, and operate on disk images.

It is relevant prior art for disk-image handling, especially for systems that use Discoverable Disk Images.

### Discoverable Disk Images

Discoverable Disk Images provide a structured systemd-aware disk-image model.

StorageGraft does not require Discoverable Disk Images, but the format is relevant prior art for image-backed systems.

## Filesystem and volume-management systems

### LVM and device mapper

LVM and device mapper provide block-layer volume management.

When a true block-level volume-management solution is available and appropriate, it may be a better fit than StorageGraft.

StorageGraft is most useful when block-level extension is unavailable, risky, inconvenient, late-available, or not general enough.

### Btrfs

Btrfs provides filesystem-native capabilities such as subvolumes, snapshots, and multi-device filesystems.

Btrfs can solve some storage-extension problems at the filesystem layer. StorageGraft should not duplicate those capabilities.

Btrfs remains relevant both as a possible store backend and as a reminder that true filesystem-level extension is different from grafting.

### ZFS

ZFS provides pooled storage, datasets, properties, mountpoint management, delegation, quotas, and snapshots.

StorageGraft should learn from ZFS’s administrative grammar:

- named storage units
- explicit properties
- mount behavior as configuration
- delegation
- status visibility
- clear separation between pools, datasets, and mount points

StorageGraft should not try to become ZFS.

### RAID

RAID composes multiple storage devices below the filesystem layer.

RAID teaches that composed storage must expose health, redundancy, failure, and degradation state.

StorageGraft should report store suitability and risk rather than treating all mounted stores as equivalent.

## Union, pooling, and remapping filesystems

### mergerfs

mergerfs is a FUSE union filesystem that can present multiple storage locations as one pooled filesystem.

mergerfs is highly relevant when the desired outcome is broad pooled storage rather than individual grafts.

StorageGraft may use a mergerfs mount as a store, or defer to mergerfs when pooling is the actual requirement.

### OverlayFS

OverlayFS presents merged directory trees using lower and upper layers.

OverlayFS is important prior art for layered filesystem views. It is not the default StorageGraft mechanism because overlay semantics differ from direct relocation and bind exposure.

### bindfs

bindfs is a FUSE filesystem that can mirror a directory tree while altering ownership and permission presentation.

bindfs is relevant when ordinary bind mounts are not enough because permission translation is required.

StorageGraft should use or integrate with bindfs rather than implementing permission translation itself.

## Network, distributed, and decentralized storage

### NFS

NFS provides network-mounted filesystems.

An NFS mount can be used as a store if it is mounted, writable when needed, and suitable for the requested grafts.

### SMB/CIFS

SMB/CIFS provides network file sharing commonly used by NAS systems.

As with NFS, a mounted SMB/CIFS share may be usable as a store depending on its permissions, durability, and workload suitability.

### CephFS

CephFS provides a distributed filesystem.

A mounted CephFS filesystem can be used as a store, subject to policy and suitability checks.

### GlusterFS

GlusterFS provides distributed filesystem storage.

A mounted GlusterFS filesystem can be treated as a store if its semantics match the intended grafts.

### sshfs

sshfs mounts remote filesystems through SSH using FUSE.

sshfs is useful prior art for user-space, network-backed storage. It may be suitable for some user data but should be treated cautiously for system paths or latency-sensitive workloads.

### rclone mount

`rclone mount` exposes cloud or remote storage through FUSE.

StorageGraft may treat an rclone mount as a store, but store suitability must account for FUSE, network latency, caching, and backend semantics.

### WebDAV/FUSE

WebDAV and similar FUSE-backed mounts can expose remote storage locally.

They may be useful for some data, but should not be assumed to provide full local POSIX filesystem behavior.

### IPFS MFS/FUSE

IPFS Mutable File System mounts are relevant to decentralized storage use cases.

An IPFS-backed store should be treated as a special kind of FUSE/network store with explicit suitability and persistence considerations.

### Hyperdrive FUSE

Hyperdrive can expose peer-to-peer storage through a FUSE mount.

A Hyperdrive-backed store should be considered possible when mounted locally, but its semantics, availability, synchronization model, and durability must be considered before grafting important data into it.

## Desktop and user-session storage

### GNOME GVfs

GVfs shows how a desktop environment handles heterogeneous local, remote, removable, and user-session storage.

The main lesson for StorageGraft is backend humility: mounted storage can come from many sources and may not have identical semantics.

StorageGraft should distinguish between:

- system-level stores
- user-session stores
- FUSE-backed stores
- remote stores
- removable stores
- local POSIX stores

Mounted does not automatically mean suitable.

## systemd image and namespace precedents

### `RootImage=`

systemd can run a service with a filesystem hierarchy from a disk image or block device.

This is relevant prior art for image-backed execution environments.

### `BindPaths=`

systemd service units can bind paths into a service namespace.

This is relevant prior art for declarative bind-mount relationships.

### `BindReadOnlyPaths=`

systemd can also expose bind-mounted paths read-only inside a service namespace.

This is relevant to future read-only graft or protection modes.

### Portable Services

Portable Services package service trees as images or directories that can be attached to a host system.

They are relevant prior art for attachable filesystem trees and systemd-managed image lifecycle.

### `systemd-nspawn`

`systemd-nspawn` supports image-backed systems, bind mounts, and related namespace composition.

It is relevant prior art for composing filesystems and namespaces without making StorageGraft a container system.

### `systemd-sysext`

`systemd-sysext` extends system hierarchies such as `/usr` and `/opt` from extension images or directories.

It is especially relevant as precedent for image-based system extension, though its use case differs from StorageGraft’s writable graft model.

### `systemd-confext`

`systemd-confext` extends configuration hierarchies.

It is relevant prior art for controlled filesystem extension, but StorageGraft should treat configuration grafts cautiously.

## Migration and safety tools

### `rsync`

`rsync` is a mature tool for copying directory trees while preserving metadata.

StorageGraft may use `rsync` or rsync-like semantics for migration and merge operations.

### `flock`

`flock` provides advisory locking.

StorageGraft should use locking around reconciliation operations to avoid concurrent mutation of the same store or graft set.

### Plan/apply workflows

Plan/apply workflows are common in infrastructure tools.

StorageGraft should produce an inspectable plan before applying operations that move, merge, remove, or hide data.

## Lessons for StorageGraft

StorageGraft should use the existing field as follows:

- Use mounted filesystems as stores.
- Use systemd for lifecycle where possible.
- Use `mount` and bind mounts for graft exposure.
- Use existing loop-device mechanisms for disk-image stores.
- Use existing network, FUSE, distributed, and pooled filesystems as store providers.
- Use existing volume managers when true volume-level extension is the right answer.
- Use conservative migration and merge semantics.
- Report store suitability and risk.
- Refuse unsafe grafts by default.

StorageGraft’s role is not to replace storage systems.

StorageGraft’s role is to reconcile storage grafts across them.