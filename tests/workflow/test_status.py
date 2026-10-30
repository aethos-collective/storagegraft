#!/usr/bin/env python3
"""Offline test of actual inline poster, with HTTP mocked; no provider claim."""
import contextlib
import io
import json
import os
import pathlib
import re
import textwrap
import unittest
from unittest.mock import patch

ROOT = pathlib.Path(__file__).resolve().parents[2]
WORKFLOW = (ROOT / '.github/workflows/git-policy.yml').read_text()
BLOCKS = re.findall(r"          python3 - <<'PYCODE'\n(.*?)          PYCODE", WORKFLOW, re.S)

class StatusTests(unittest.TestCase):
    def post(self, state, sha='a' * 40):
        requests = []
        def respond(request, timeout):
            requests.append(request)
            return io.BytesIO(json.dumps({'state': state, 'context': 'git-policy/trusted-head'}).encode())
        env = dict(TARGET_SHA=sha, GITHUB_REPOSITORY='example/project', STATUS_STATE=state,
                   RUN_URL='https://github.com/example/project/actions/runs/1',
                   GITHUB_API_URL='https://api.github.com', GH_TOKEN='test-only')
        with patch.dict(os.environ, env), patch('urllib.request.urlopen', respond), contextlib.redirect_stdout(io.StringIO()):
            exec(compile(textwrap.dedent(BLOCKS[0]), 'inline-poster', 'exec'), {})
        return requests

    def test_pending_success_failure_exact_sha(self):
        self.assertEqual(len(BLOCKS), 2)
        self.assertEqual(BLOCKS[0], BLOCKS[1])
        for state in ['pending', 'success', 'failure']:
            with self.subTest(state=state):
                requests = self.post(state)
                self.assertEqual(len(requests), 1)
                self.assertEqual(requests[0].full_url, 'https://api.github.com/repos/example/project/statuses/' + 'a' * 40)
                self.assertEqual(json.loads(requests[0].data)['context'], 'git-policy/trusted-head')
                self.assertEqual(json.loads(requests[0].data)['state'], state)

    def test_bad_sha_no_post(self):
        with self.assertRaises(SystemExit): self.post('success', '1/merge')

    def test_missing_policy_not_success_expression(self):
        self.assertIn("steps.validate.outcome == 'success' && 'success' || 'failure'", WORKFLOW)
        self.assertIn('if: ${{ always() }}', WORKFLOW)
        self.assertIn('github.event.pull_request.head.sha', WORKFLOW)
        self.assertNotIn('pull_request.head.ref }}', WORKFLOW)
        self.assertNotIn('ref: ${{ github.event.pull_request.head.sha', WORKFLOW)

if __name__ == '__main__': unittest.main()
