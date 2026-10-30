#!/usr/bin/env python3
"""Print proposed ruleset request bodies. Does not make API calls."""
import argparse
import json
import pathlib

parser = argparse.ArgumentParser()
parser.add_argument('--actions-app-id', type=int, required=True, help='Observed app.id from actual required check runs')
a = parser.parse_args()
if a.actions_app_id <= 0:
    parser.error('app ID must be a positive observed integer')
root = pathlib.Path(__file__).resolve().parents[2]
p = json.loads((root / '.workflow/git-workflow.json').read_text())
b = json.loads((root / '.workflow/repository.json').read_text())
g = p['grammar']

def ruleset(name, target, include, exclude, rules):
    return dict(name=name, target=target, enforcement='disabled', bypass_actors=[],
                conditions={'ref_name': {'include': include, 'exclude': exclude}}, rules=rules)

integration = ['refs/heads/' + g['trunk']] + ['refs/heads/' + x for x in b['supported_maintenance']]
# fnmatch only: one slash-separated namespace; grammar remains a trusted CI check.
allowed = integration + ['refs/heads/' + t + '/' + b['issue_key'] + '-*' for t in g['types']]
result = [
    ruleset('git-policy: reject other branch namespaces', 'branch', ['~ALL'], allowed, [{'type': 'creation'}]),
    ruleset('git-policy: reviewed integration', 'branch', integration, [], [
        {'type': 'deletion'}, {'type': 'non_fast_forward'},
        {'type': 'pull_request', 'parameters': {
            'dismiss_stale_reviews_on_push': True,
            'require_code_owner_review': True, 'require_last_push_approval': True,
            'required_approving_review_count': 1, 'required_review_thread_resolution': True}},
        {'type': 'required_status_checks', 'parameters': {
            'do_not_enforce_on_create': False, 'strict_required_status_checks_policy': True,
            'required_status_checks': [{'context': x, 'integration_id': a.actions_app_id}
                for x in ['git-policy/trusted-head', 'git-policy / tooling-tests']]}}
    ]),
    ruleset('git-policy: release tag namespace', 'tag', ['~ALL'], ['refs/tags/v[0-9]*'], [{'type': 'creation'}]),
    ruleset('git-policy: immutable release namespace', 'tag', ['refs/tags/v[0-9]*'], [], [{'type': 'update'}, {'type': 'deletion'}])
]
print(json.dumps(result, indent=2))
