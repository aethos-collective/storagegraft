# Contributing

Start with the [generated Git workflow contract](docs/git-workflow.md).
The exact pinned distribution is [.workflow/git-workflow.json](.workflow/git-workflow.json);
its logical identity and revision resolve to the cross-project contract maintained
by the policy stewards. This repository is a consumer, not the canonical editing home.

From a clean checkout, create a topic using a copied identifier-title:

```sh
./tools/workflow/new-branch docs sg-35-add-examples-documentation-and-sample-configuration-files
```

The helper only creates and switches a branch at the current commit; it does not
create a worktree or select/fetch a base. It requires the caller and the script to
belong to the same Git worktree, and refuses another checkout or a non-repository
working directory. It then runs Git explicitly in that verified worktree.

For an independent task, choose a reviewed base and an unused worktree path,
create the worktree yourself, then invoke its own copy of the helper. For example,
after verifying that `origin/main` is the intended base:

```sh
git worktree add --detach ../storagegraft-task origin/main
cd ../storagegraft-task
./tools/workflow/new-branch docs sg-35-add-examples-documentation-and-sample-configuration-files
```

This example requires the tooling to exist in the selected base. The helper never
moves work between checkouts or installs hooks automatically.

Optional local hook activation (inspect any existing hooks first):

```sh
git config --local core.hooksPath .githooks
```

This changes only this clone's Git configuration. Coordinate existing hook managers;
do not overwrite them. The hook checks every destination, including refspec aliases,
multiple pushes and deletions. Removing an invalid legacy branch therefore needs an
explicit one-operation local hook bypass; server authorization still applies.

Run portable workflow tests with `sh tests/workflow/run.sh`. These tests are
independent of the component baseline and do not need Python. Regeneration and
artifact drift checks use Python 3.10+ standard library only:

```sh
python3 tools/workflow/generate.py
python3 tools/workflow/generate.py --check
```

The generator emits grammar, digest and human guidance deterministically. The
repository binding supplies only the issue key and supported lines, plus its policy
identity. Obtain a reviewed canonical revision, replace the payload byte for byte,
update the binding pin and regenerate; do not edit the distributed payload in place
as a local exception. A matching digest is not evidence that stewards approved it.

See [activation and evidence plan](docs/workflow-enforcement.md) before enabling
server requirements. Repository administration is a separate reviewed operation.
