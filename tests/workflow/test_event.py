#!/usr/bin/env python3
"""CI adapter fixtures, including hostile fork metadata and queue fail-closed."""
import json
import os
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]

class EventTests(unittest.TestCase):
    def run_event(self, event, name='pull_request_target'):
        with tempfile.NamedTemporaryFile(mode='w') as f:
            json.dump(event, f); f.flush()
            return subprocess.run(['python3', str(ROOT / 'tools/workflow/check-event.py')],
                env=dict(os.environ, GITHUB_EVENT_NAME=name, GITHUB_EVENT_PATH=f.name),
                capture_output=True).returncode

    def pr(self, head, base='main'):
        return {'pull_request': {'head': {'ref': head, 'repo': {'fork': True}}, 'base': {'ref': base}}}

    def test_fork_head(self):
        self.assertEqual(self.run_event(self.pr('fix/sg-1-repair')), 0)

    def test_rejections(self):
        for head in ['bad', '1/merge', 'main', 'fix/sg-1-a\nfix/sg-2-b', 'fix/sg-1-$(touch marker)']:
            with self.subTest(head=head): self.assertNotEqual(self.run_event(self.pr(head)), 0)

    def test_unsupported_base(self):
        self.assertNotEqual(self.run_event(self.pr('fix/sg-1-repair', 'release/1.0.x')), 0)

    def test_topic_base_rejected(self):
        self.assertNotEqual(self.run_event(self.pr('fix/sg-1-repair', 'docs/sg-2-topic')), 0)

    def test_queue_fails_closed(self):
        self.assertNotEqual(self.run_event({'merge_group': {'head_ref': 'gh-readonly-queue/main/pr-1'}}, 'merge_group'), 0)

    def test_other_event_fails_closed(self):
        self.assertNotEqual(self.run_event({}, 'push'), 0)

if __name__ == '__main__': unittest.main()
