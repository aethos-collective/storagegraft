# Git workflow

Generated from `git-workflow.json`; do not edit this view.

Logical contract: `aethos.git-workflow` revision `1.0.0`.

## Scope

Cross-project contribution workflow; repositories bind their issue key and supported maintenance lines. No component runtime semantics are authorized by this policy.

## Acceptance

The workflow principles are accepted and implementation of the enforcement design is authorized. Deployment and repository-setting activation require separate review; private acceptance evidence is retained separately.

## Workflow

- Use main as the single development trunk; no permanent develop line is required.
- Use short, reviewed topic branches. Keep one independent task per branch and worktree.
- Prefer merge commits to preserve meaningful original commit provenance. Selective squash is allowed for disposable fixups; do not mandate squash or rebase or blanket-disable merge options. Preserve accurate authorship and identify assistance without impersonation.
- Create supported release/maintenance lines only for documented support obligations. Record each supported line explicitly in the repository binding. Use tested, versioned release tags as a separate ref class.
- Topic names contain purpose, issue identifier and a lowercase hyphenated description. Do not prefix branches with a provider or agent name.
- Use existing issue and specification records; preserve imported issue correspondence and do not create duplicate plans.
- Make policy changes in the canonical contract, review a new revision, then distribute exact bytes and regenerate derived guidance. Repository distributions are pins, not independent masters.

## Traceability

- Pull requests identify the existing issue, specification or decision dependency, tests and results, and actual authors and assistance.
- Separate accepted requirements from proposals. Report blockers and unmet dependencies explicitly; branch grammar cannot prove issue existence or specification acceptance.

## Enforcement design

- Local helpers and hooks provide feedback and can be bypassed; server review and required checks form the enforcement boundary.
- Native creation restrictions enforce namespaces only. Full branch grammar requires trusted CI, or separately available server metadata rules.
- Policy and checker changes require review against the previously trusted version. A digest proves byte identity, not authority.
- Required-check source identity, fork behavior and merge queue behavior require live validation before enforcement is declared effective. No automation bypass is implicit.

## Complete grammar and source identity

Source SHA-256: `98208e25e0b0ae823e0af47de2bd77d5828c8519da746b8b2d15d9bfa96ebad6`.

```json
{
  "dialect": "POSIX ERE, C locale, whole string",
  "types": [
    "feature",
    "fix",
    "docs",
    "refactor",
    "perf",
    "test",
    "build",
    "ci",
    "chore",
    "revert"
  ],
  "issue_number": "[1-9][0-9]*",
  "description": "[a-z0-9]+(-[a-z0-9]+)*",
  "trunk": "main",
  "maintenance": "release/[0-9]+\\.[0-9]+\\.x",
  "tag": "v(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(-[a-z0-9]+([.-][a-z0-9]+)*)?",
  "topic_template": "{type}/{issue_key}-{issue_number}-{description}"
}
```
