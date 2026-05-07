# Migration Semantics

StorageGraft migrates or merges data from an origin address into a corresponding store subtree before activating a graft.

Migration is the most safety-critical part of the project. A bind mount can hide existing data if it is placed over a non-empty origin address too early. StorageGraft therefore inspects, plans, migrates or merges, verifies, and only then binds.

## Core invariant

For a store root and origin address:

```text
store subtree = store root + origin address
```

Example:

```text
store root:
  /mnt/store

origin address:
  /home/<user>/example

store subtree:
  /mnt/store/home/<user>/example
```

Migration moves data from the origin address into the store subtree.

The graft then bind-mounts the store subtree back onto the origin address.

## State model

StorageGraft evaluates the origin address and store subtree before acting.

The relevant states are:

```text
origin absent
origin empty
origin non-empty
store subtree absent
store subtree empty
store subtree non-empty
already grafted
conflict detected
```

StorageGraft distinguishes directory existence from directory contents.

An existing empty directory is not the same as a non-empty directory.

An absent store subtree can be created.

An absent origin address can be created only when policy allows it.

## Safe cases

### Origin empty, store subtree empty

Action:

```text
create missing directories if needed
bind store subtree onto origin address
```

No data movement is required.

### Origin empty, store subtree non-empty

Action:

```text
bind store subtree onto origin address
```

The store already contains the data to expose.

### Origin non-empty, store subtree absent or empty

Action:

```text
create store subtree
copy origin contents into store subtree
verify copied contents
clear origin contents
bind store subtree onto origin address
```

This is migration.

### Origin non-empty, store subtree non-empty, no conflicts

Action:

```text
merge non-conflicting origin contents into store subtree
verify merged contents
clear migrated origin contents
bind store subtree onto origin address
```

This is an additive merge.

StorageGraft must not overwrite existing store contents during an automatic merge.

### Already grafted

Action:

```text
no action
```

StorageGraft should verify that the active bind mount points to the expected store subtree.

## Unsafe cases

### Origin non-empty, store subtree non-empty, conflicts detected

Action:

```text
stop
report conflict
require manual merge decision
```

StorageGraft must not overwrite, replace, rename, or discard conflicting data automatically.

### Origin path is not a directory

Action:

```text
stop
report unsupported origin type
```

StorageGraft supports directory grafts.

### Store subtree path is not a directory

Action:

```text
stop
report unsupported store subtree type
```

StorageGraft supports directory grafts.

### Origin is already a mount point owned by something else

Action:

```text
stop
report existing mount conflict
```

StorageGraft must not place a graft over an unrelated active mount.

### Origin or store subtree resolves through unsafe symlinks

Action:

```text
stop
report symlink or path-resolution hazard
```

StorageGraft avoids acting through path structures that can redirect operations outside the intended origin or store boundary.

## Conflict definition

A conflict occurs when the same relative address exists in both the origin and the store subtree and StorageGraft cannot safely combine them without changing or replacing an existing object.

Examples:

```text
same relative file exists on both sides
file exists on one side and directory exists on the other
regular file exists on one side and symlink exists on the other
filesystem object type mismatch
unsupported special file collision
```

Directories with the same relative address are not conflicts by themselves. StorageGraft should recurse into them and evaluate their contents.

Example without conflict:

```text
origin:
  project-a/

store subtree:
  project-b/

result:
  automatic additive merge allowed
```

Example without conflict:

```text
origin:
  src/main.c

store subtree:
  docs/readme.md

result:
  automatic additive merge allowed
```

Example with conflict:

```text
origin:
  notes.txt

store subtree:
  notes.txt

result:
  conflict
```

Example with conflict:

```text
origin:
  src/ as directory

store subtree:
  src as regular file

result:
  conflict
```

## Migration requirements

StorageGraft migration must be direct, verified, and conservative.

### Direct destination

StorageGraft migrates directly into the final store subtree.

It does not use temporary directory trees as its migration design pattern.

Example:

```text
origin:
  /home/<user>/example

store subtree:
  /mnt/store/home/<user>/example
```

Data moves directly into:

```text
/mnt/store/home/<user>/example
```

### Verification before cleanup

StorageGraft verifies copied or merged data before clearing origin contents.

Verification should confirm that expected relative entries exist in the store subtree after migration or merge.

Implementations may support stronger verification modes, such as metadata checks or checksum-based verification.

### Cleanup after verification

StorageGraft clears origin contents only after successful verification.

The origin directory itself remains as the mount point.

StorageGraft removes contents inside the origin directory, not the origin directory itself.

### Bind after cleanup

StorageGraft activates the bind mount only after migration or merge cleanup is complete.

The bind direction is:

```text
mount --bind <store subtree> <origin address>
```

Example:

```text
mount --bind /mnt/store/home/<user>/example /home/<user>/example
```

## Additive merge semantics

An automatic merge is additive only.

StorageGraft may copy entries from the origin into the store subtree when those entries do not already exist at the same relative address.

StorageGraft must not automatically overwrite existing files in the store subtree.

StorageGraft must not automatically replace an existing directory with a file, a file with a directory, a symlink with a regular file, or any other conflicting filesystem object.

## Permissions and ownership

Migration should preserve ownership, permissions, timestamps, symlinks, and ordinary metadata where the store supports them.

If the store cannot preserve required metadata, StorageGraft should report a suitability warning or refuse the graft depending on the path class and policy.

A POSIX-capable store is preferred for executable trees, development workspaces, local administrator software, and system paths.

## Store suitability

A store may be mounted and writable but still unsuitable for a given graft.

Examples:

```text
A POSIX filesystem may be suitable for executable development trees.

A host-shared removable filesystem may be suitable for documents but unsuitable for executable files.

A FUSE or network filesystem may be suitable for user data but unsuitable for critical system state.
```

StorageGraft should consider store suitability before migration.

## User declarations

User path lists are declarations, not authority.

A user-declared origin address must be validated before use.

For home-scoped user declarations, StorageGraft should require that the origin address remains inside that user’s home directory and does not resolve outside it.

System path lists are root-owned policy.

## Failure handling

If migration fails before cleanup, origin contents remain in place.

If verification fails, origin contents remain in place.

If cleanup fails, StorageGraft stops before binding.

If bind mounting fails after successful migration and cleanup, StorageGraft reports that the data has been moved but the graft is not active.

Status output should make this condition visible.

## Idempotency

StorageGraft operations must be safe to retry.

A repeated reconciliation should not duplicate data, overwrite data, or create duplicate mounts.

StorageGraft should recognize:

```text
already migrated but not bound
already bound correctly
store subtree exists with data
origin still contains data
origin cleared and ready as mount point
```

and choose the appropriate next action.

## Required behavior

StorageGraft should provide plan, apply, and status behavior.

Plan behavior:

```text
inspect origin and store subtree
detect empty and non-empty states
detect conflicts
report intended action
report refused action
```

Apply behavior:

```text
support directory grafts
migrate or additive-merge when safe
verify before cleanup
bind after cleanup
refuse conflicts
```

Status behavior:

```text
report whether stores are mounted
report whether grafts are active
report whether data has been migrated
report whether origin content may be hidden or unmigrated
report conflicts and refused actions
```