# Command Model

StorageGraft is operated through explicit commands.

The command model is plan-first. Inspection commands make storage state legible before any command changes storage or mount state.

## Current implementation

The current implementation provides:

```text
storagegraft check
storagegraft status [store]
storagegraft plan [store]
```

These commands are non-mutating.

They do not:

```text
migrate data
merge data
clear origin contents
activate bind mounts
unmount grafts
mount stores
generate systemd units
install systemd units
remove systemd units
```

## Implementation target

The current executable is implemented as strict POSIX shell.

The implementation target is:

```text
/bin/sh
strict POSIX shell
BusyBox-conscious utilities where practical
systemd for managed lifecycle integration
standard Linux mount tooling
```

StorageGraft does not require Bash, Zsh, Python, Perl, or another scripting runtime.

## `storagegraft check`

`check` validates discoverable configuration and reports obvious problems.

It does not change storage state.

Current behavior includes:

```text
reports the system configuration root
detects the system main configuration file
discovers system stores
discovers user main configuration files
discovers user stores
reports matching path-list files
reports missing store roots
```

Example:

```text
storagegraft check
```

From a checkout:

```text
./sbin/storagegraft.sh check
```

## `storagegraft status [store]`

`status` reports observed store state.

It does not change storage state.

Current behavior includes:

```text
reports configured stores
reports configuration plane
reports store owner
reports store root
reports whether the store root is mounted
reports mount source when mounted
reports filesystem type when mounted
reports activation mode
reports managed flag
reports kind
reports semantics
reports durability
reports user path availability for system stores when users=allow
```

Examples:

```text
storagegraft status
storagegraft status main
```

From a checkout:

```text
./sbin/storagegraft.sh status
./sbin/storagegraft.sh status main
```

## `storagegraft plan [store]`

`plan` inspects configured stores, path lists, origin addresses, store subtrees, and active mount state.

It does not change storage state.

Current behavior includes:

```text
reads system store declarations
reads user store declarations
reads system path lists
reads user path lists
resolves relative path-list entries
computes store subtrees
checks whether store roots are mounted
classifies origin address state
classifies store subtree state
reports intended non-mutating action
reports refused actions
```

Examples:

```text
storagegraft plan
storagegraft plan main
```

From a checkout:

```text
./sbin/storagegraft.sh plan
./sbin/storagegraft.sh plan main
```

## Store-scoped commands

Current inspection commands accept an optional store name.

Example:

```text
storagegraft plan main
storagegraft status main
```

When no store name is provided, StorageGraft processes all discoverable stores.

## Configuration override

The system configuration root defaults to:

```text
/etc/storagegraft
```

For testing or development, the configuration root can be overridden with:

```text
STORAGEGRAFT_ETC=/path/to/test/etc
```

Example:

```text
STORAGEGRAFT_ETC=/path/to/test/etc ./sbin/storagegraft.sh plan
```

## Current plan actions

The current planner reports intended actions.

It does not execute them.

Current plan actions include:

```text
create-and-bind
bind
migrate-verify-bind
merge-or-conflict-check-required
inspect
wait
refused
```

## `create-and-bind`

Reported when both the origin address and store subtree are absent.

Meaning:

```text
the origin address and store subtree need to be created before a bind graft can be activated
```

This action is not implemented yet.

## `bind`

Reported when the store subtree can be exposed at the origin address without migration.

Examples:

```text
origin is empty, store subtree is empty
origin is empty, store subtree has data
origin is absent, store subtree has data
```

This action is not implemented yet.

## `migrate-verify-bind`

Reported when the origin address has data and the store subtree is absent or empty.

Meaning:

```text
copy origin contents into the store subtree
verify copied contents
clear origin contents after verification
bind the store subtree onto the origin address
```

This action is not implemented yet.

## `merge-or-conflict-check-required`

Reported when both the origin address and store subtree contain data.

Meaning:

```text
StorageGraft needs recursive conflict detection before deciding whether an additive merge is safe
```

This is a planning-stage placeholder.

The next implementation milestone is recursive conflict scanning so this state can become either:

```text
merge-verify-bind
```

or:

```text
refused / conflict
```

## `inspect`

Reported when the origin address is already a mount point.

Meaning:

```text
StorageGraft needs to determine whether the mount is already the expected graft or an unrelated mount
```

Current implementation reports the condition without changing it.

## `wait`

Reported when the store root is not mounted.

Meaning:

```text
the store is unavailable
no migration or bind action can proceed
```

## `refused`

Reported when StorageGraft detects an invalid or unsafe condition.

Examples:

```text
invalid store
invalid root
pseudo-runtime path
origin outside allowed user scope
origin is a symlink
store subtree is a symlink
unsupported object type
unknown state
```

## Planned commands

The planned command surface includes:

```text
storagegraft apply
storagegraft reconcile
storagegraft mount <store>
storagegraft unmount <store>
storagegraft enable <store>
storagegraft disable <store>
storagegraft doctor
```

These commands are not implemented in the current POSIX shell planner.

## `storagegraft apply`

`apply` executes safe planned actions.

Planned apply behavior:

```text
create missing directories
migrate data
merge non-conflicting data
verify copied or merged data
clear origin contents after verification
activate bind mounts
refuse conflicts
```

`apply` requires reliable planning and conflict detection before implementation.

## `storagegraft reconcile`

`reconcile` is the command intended for systemd invocation.

Planned reconcile behavior:

```text
inspect current state
perform safe non-interactive actions
refuse ambiguous or unsafe grafts
report failures clearly
remain idempotent
```

`reconcile` does not require interactive input.

## `storagegraft mount <store>`

`mount` brings a managed store online.

For unmanaged stores, it reports that the store is externally mounted.

StorageGraft uses systemd where possible for managed store lifecycle.

## `storagegraft unmount <store>`

`unmount` removes grafts using a store before unmounting the store itself.

It does not delete data.

Unmount order accounts for nested grafts.

## `storagegraft enable <store>`

`enable` enables systemd-managed activation for a managed store.

For an `auto-late` store, this may enable associated `.path` and `.timer` units rather than directly enabling the `.mount` unit.

## `storagegraft disable <store>`

`disable` disables automatic activation for a managed store.

It does not delete store data, path lists, or store configuration.

## `storagegraft doctor`

`doctor` performs broader diagnostics.

Planned diagnostic areas include:

```text
systemd unit state
mount state
store readiness
store suitability
filesystem type
available space
failed units
missing stores
conflicting declarations
unsafe file ownership
unsafe file permissions
```

`doctor` is non-mutating.

## Output model

StorageGraft uses human-readable output by default.

Future implementations may add machine-readable output.

Potential output modes:

```text
text
json
```

The current implementation supports text output only.

## Plan output

Plan output separates:

```text
stores
grafts
observed state
intended actions
policies
warnings
refusals
```

Example structure:

```text
STORE main
  plane: system
  owner: root
  config: /etc/storagegraft/stores.d/main.conf
  root: /mnt/store
  state: mounted

GRAFT /home/<user>/example
  plane: user
  owner: <user>
  declaration: /home/<user>/.storagegraft/paths.d/main.paths:1
  store: main
  store root: /mnt/store
  store subtree: /mnt/store/home/<user>/example
  origin state: non-empty
  store subtree state: empty
  action: migrate-verify-bind
  policy: safe
```

## Status output

Status output reports observed store state.

Example structure:

```text
STORE main
  plane: system
  owner: root
  config: /etc/storagegraft/stores.d/main.conf
  root: /mnt/store
  state: mounted
  source: /dev/example
  filesystem: ext4
  activation: external
  managed: false
  kind: filesystem
  semantics: posix
  durability: backend-defined
```

## Exit behavior

StorageGraft commands use meaningful exit status codes.

Current implementation has minimal exit-code behavior.

Target exit behavior:

```text
0:
  success

1:
  command failed

2:
  invalid command or invalid arguments

3:
  configuration error

4:
  unsafe state or refused action

5:
  store unavailable

6:
  conflicts detected
```

## Privilege behavior

Inspection commands run without root when possible.

Current inspection commands:

```text
storagegraft check
storagegraft status
storagegraft plan
```

Mutation commands generally require root.

Planned mutation commands:

```text
storagegraft apply
storagegraft reconcile
storagegraft mount
storagegraft unmount
storagegraft enable
storagegraft disable
```

When root is required, StorageGraft fails clearly rather than partially applying changes.

## Interactivity

`check`, `status`, and `plan` are non-interactive.

`reconcile` is non-interactive because it is intended for systemd invocation.

Manual commands such as `apply` and `unmount` may support interactive confirmation.

Automation may use an explicit non-interactive option when implemented.

Example planned form:

```text
storagegraft apply --yes
```

## Idempotency

Commands that change state are idempotent where possible.

Repeated mutation commands do not:

```text
duplicate data
overwrite data
create duplicate bind mounts
remove data unexpectedly
hide data unexpectedly
```

Already-satisfied state results in no action.

## Normal workflow

Current non-mutating workflow:

```text
storagegraft check
storagegraft status
storagegraft plan
```

Planned mutating workflow:

```text
storagegraft check
storagegraft plan
storagegraft apply
storagegraft status
```

Planned systemd-managed workflow:

```text
storagegraft reconcile
```