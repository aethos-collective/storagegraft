# Distribution format

The machine-readable structural schema is `git-workflow.schema.json` (JSON Schema
2020-12). It constrains shape without duplicating normative vocabulary. No schema
validator package is required for normal tooling.

Version 1 uses UTF-8 JSON with a terminating newline. Hash the exact file bytes
with SHA-256; do not reserialize between canonical publication and distribution.
`git-workflow.json` is the authoritative payload. `repository.json` is a binding,
not an override. Python 3.10+ is needed only by generation and CI adapters.

| Payload key | Shape and meaning |
| --- | --- |
| schema_version | Integer 1; structural format version |
| id | Stable logical policy identity |
| revision | Version string for reviewed policy revisions |
| scope | Public-safe scope explanation |
| acceptance | Public-safe acceptance/rollout distinction; no private evidence IDs |
| workflow | Array of normative human-readable commitments |
| grammar | Dialect, purpose vocabulary, number/description ERE fragments, trunk, maintenance/tag ERE and topic template |
| traceability | Array of issue/specification/test/authorship requirements |
| enforcement_design | Array distinguishing mechanisms from verified enforcement |

The topic template uses only `type`, `issue_key`, `issue_number` and `description`.
Generated regular expressions are anchored, evaluated in the C locale, and reject
embedded newlines. Branch, integration target and tag validation are separate.
Maintenance refs additionally require membership in `supported_maintenance`.

The binding has `schema_version`, `policy_id`, `policy_revision`, `issue_key`
(lowercase ASCII letter followed by lowercase letters/digits), and
`supported_maintenance` (unique branch-name strings). Support justification lives
in the linked issue/decision, not a competing grammar in the binding.

Generated files are `grammar.sh`, `policy.sha256`, `CONTRACT.md` and
`docs/git-workflow.md`. `CONTRACT.md` depends only on the payload and is suitable
for the canonical readable view. The repository guide adds binding information.
`generate.py --check` compares exact bytes. Runtime code does not load this policy.
