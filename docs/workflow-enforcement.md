# Activation and evidence plan

This is an implementation plan for the [generated contract](git-workflow.md),
not another source of normative workflow rules. No server settings were changed
by preparing these files. The initial repository had only `main`, unprotected,
and the ruleset listing was empty. Recheck those observations at rollout.

## Trust boundary

`git-policy.yml` uses `pull_request_target` to load the already trusted base
commit, with `contents: read`, `statuses: write`, and checkout credentials disabled.
This proposed permission grant is pending explicit rollout review. It does not
check out, import, source, build or execute PR content. It passes the JSON event
as data to `check-event.py`, which validates the real `pull_request.head.ref`,
including fork PRs, and the integration target. No expression containing a PR
branch, title or body is interpolated into shell code. There are no branch/path
filters. Editing the policy or validator in the PR cannot change this check's
current decision. The evaluator job is NOT the required head check: its event
context belongs to the base. The trusted workflow explicitly posts the commit
status `git-policy/trusted-head` to `pull_request.head.sha` in the base repository
using the existing GITHUB_TOKEN. It first posts pending, then success only after
both base validation and distribution checks succeed; otherwise it posts failure.
Failure to fetch the base, a missing checker, malformed metadata, token failure or
workflow interruption cannot produce a new success. A pending or missing required
status blocks integration once protection is active, but an older success on the
same SHA may remain if a new run fails before posting pending. This stale-success
and same-SHA race remains a validation/design gate, not a fail-closed guarantee. No external App, credential or service is introduced. The bootstrap PR cannot run a validator absent from its base;
manual bootstrap review is necessary before the required check is enabled.

`workflow-tests.yml` runs proposed code under `pull_request` without secrets or
write permissions on a disposable hosted runner. It checks shell behavior and
reproducible artifacts. It is not a privileged authority for its own changes.
All workflow files, policy, generated artifacts, helpers, tests and instructions
are covered by CODEOWNERS. The proposed owner has verified repository admin
permission; confirm their willingness and availability. The base CODEOWNERS and
required owner review must be operative before relying on them. A PR author
cannot supply their own approving review; another eligible steward is needed
for a steward-authored PR. No broad admin or automation bypass is proposed.

The source JSON is public-safe. Its SHA-256 pin verifies exact distributed bytes;
it does not authenticate a policy change. Stewards compare any proposed new pin
with the reviewed canonical revision. There is no fetch from a private URL.
The build-time generator uses only the Python standard library, independent of
the component runtime and portable baseline tests. Shell validators consume the
checked-in generated grammar; generation drift is checked separately.

An Actions app ID selects a producer app, not a particular workflow file.
Repository default workflow permissions should be read-only, fork PR write tokens
should remain disabled, and only this reviewed metadata workflow should request
`statuses: write`. These are proposed settings for explicit review, not changes
already made. Default permissions are not a hard cap: another same-repository
workflow can request write permission before its branch merges. Therefore whole
workflow-tree review and independent approval are essential, but cannot prove
cryptographic isolation of this context from same-app writers. Do not claim a
fully spoof-proof boundary without a separately supported trusted-workflow or
credential isolation mechanism. No new such mechanism is authorized here.
An attacker may try to create a second workflow with the same job/check name.
Protect the entire `.github/` tree and require review; inspect duplicate contexts
and do not claim app pinning alone prevents same-app spoofing. Where available,
organization required-workflow rules pinned to a protected policy source can
strengthen this; that is a separate capability and approval decision, not assumed
here. This implementation cannot defend against an authorized administrator
removing the protections or a reviewer approving a malicious checker change.

## Exact proposed administration changes

Run `python3 tools/workflow/prepare-rules.py --actions-app-id OBSERVED_ID` after
obtaining the actual `app.id` from check runs. The output is an array of four
GitHub ruleset create bodies, all initially **disabled** and all with empty bypass
lists. No network call is made. Submit each body individually only after approval.
Change `enforcement` to `active` only when the evidence gates below pass. Do not
substitute an invented app ID or omit the expected-source field.

1. Branch namespace creation: target `~ALL`, exclude main, explicitly supported
   maintenance lines, and each generated `TYPE/sg-*` namespace; restrict creation
   everywhere else. This catches invalid namespaces rather than targeting only
   already valid names. Glob matching is not a full grammar check.
2. Integration branches: target main and explicit supported lines; prohibit
   deletion and force pushes, require a PR, one approval, owner review, dismissal
   of stale approvals, approval of the latest push, resolved conversations,
   both named checks from the observed Actions app.
   Strict checks require the current base. No required linear history.
3. Tag creation: target all tags except `v[0-9]*`, restrict creation. This is
   only a namespace screen; it cannot enforce the complete version expression.
4. Release-namespace immutability: restrict updates and deletions for
   `refs/tags/v[0-9]*` only; no bypasses. Existing unrelated tags are not locked.

Prefer merge commits when original commit provenance is meaningful; selective
squash remains available for disposable fixups. No repository-wide merge-method
disablement or allowed-merge-method restriction is proposed. Keep merge queue disabled. No release
line is initially supported; adding one needs a documented support obligation,
reviewed binding and coordinated rule update before branch creation. Existing
branches in other projects are out of scope. Native full-regex metadata rules
require the applicable Enterprise capability; do not represent these glob rules
as equivalent. Topic creation under an allowed prefix, and tag creation under
`v[0-9]*`, can still have malformed suffixes. CI blocks a malformed topic from
integration, not its original push. Strict tag-creation validation needs an
additional supported server rule or controlled release process and is not
claimed implemented here. A malformed tag admitted by the broad release glob
can then be locked by immutability. Recovery requires a separately approved,
recorded administrator exception or rule correction; no silent bypass or automatic
deletion is proposed. Test that unrelated existing tags remain outside the
immutability rule. Hooks remain bypassable.

## Evidence gates (not yet executed remotely)

Use a separately authorized disposable test repository or reviewed test PRs;
record repository, rule IDs/configuration, run URLs, head/base SHAs, check-run
IDs, `app.id`/slug, conclusions and observed mergeability for each case.

- Confirm `git-policy/trusted-head` as a commit status on the actual PR head SHA,
  and `git-policy / tooling-tests` as the separate test check, with expected source;
  verify required checks/statuses attach to the evaluated PR commit, including
  fork PRs. Record the POST response, GET statuses for that exact SHA, context,
  producer identity, run URL, and actual ruleset mergeability. Do not use the
  pull_request_target job check on the base SHA as this evidence. Force a missing
  base checker and a validation failure and verify no success is posted.
  Inspect actual check runs and mergeability, not just workflow success.
- A valid topic passes; invalid purpose, missing issue, uppercase, malformed
  separator, nested suffix, and malformed fork head fail. A synthetic `N/merge`
  ref is never used as the topic name. Edit/retarget and synchronize rerun checks.
- A PR that weakens its own policy/checker still fails an invalid name under the
  base policy. Attempts to remove CODEOWNERS or add a duplicate check-name
  workflow require the existing owner's approval. Verify stale approval reset.
- Create two PRs sharing the exact head commit SHA, one with a valid name and one
  invalid, and test rename/retarget races. Commit statuses are keyed by SHA/context,
  not PR number: a success for one PR can be reused by another. This candidate
  does not yet isolate that case; do not declare strict head-name enforcement
  effective until the live behavior is resolved with a supported design.
- Wrong-app status with the same context must not satisfy the required check.
  Test same-app duplicate context behavior and document the residual limitation.
- Test native namespace creation on valid, invalid and nested branch names;
  confirm the all-branches rule applies to a previously nonexistent invalid ref.
  Test multi-ref pushes; no atomic-push guarantee is inferred from local checks.
- Verify direct integration pushes, force pushes, deletions and unreviewed policy
  edits are rejected; a reviewed valid PR can merge using a merge commit.
- Verify tag namespace failures and update/delete rejection. Record malformed
  version suffixes that remain possible under glob-only creation restrictions.
- Queue behavior is deliberately fail-closed: `merge_group` returns failure.
  Before enabling a queue, implement trusted constituent-PR lookup and validation,
  prove which commit receives both required checks, and test a group containing
  valid and invalid heads. A queue ref must never be treated as an ordinary topic.

Do not enable a required context that is missing or attached to the wrong SHA.
If current source identity cannot be established, leave activation pending.
Bootstrap: review and land tooling first through an explicitly reviewed process,
observe real checks, review exact rendered rules, then separately approve settings.
Recovery is an audited administrator action with a recorded reason and minimal
scope; never silently add a permanent bypass. This plan itself grants no admin
mutation authority.

## Provider references

- [Rules REST API](https://docs.github.com/en/rest/repos/rules)
- [Available rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)
- [Workflow events and security](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows)
- [Required-check troubleshooting](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks)
