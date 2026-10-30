#!/usr/bin/env python3
"""Prove regeneration, drift detection and repository-independent issue binding."""
import json
import pathlib
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]

class GenerationTests(unittest.TestCase):
    def test_binding_and_drift(self):
        with tempfile.TemporaryDirectory() as tmp:
            dest = pathlib.Path(tmp)
            for directory in ['.workflow', 'tools/workflow', 'docs']:
                shutil.copytree(ROOT / directory, dest / directory)
            def generate(*args):
                return subprocess.run(['python3', str(dest / 'tools/workflow/generate.py'), *args], capture_output=True)
            self.assertEqual(generate('--check').returncode, 0)
            old_payload = (dest / '.workflow/git-workflow.json').read_bytes()
            old_view = (dest / '.workflow/CONTRACT.md').read_bytes()
            b = json.loads((dest / '.workflow/repository.json').read_text())
            b['issue_key'] = 'xy'
            (dest / '.workflow/repository.json').write_text(json.dumps(b))
            self.assertNotEqual(generate('--check').returncode, 0)
            self.assertEqual(generate().returncode, 0)
            self.assertEqual(old_payload, (dest / '.workflow/git-workflow.json').read_bytes())
            self.assertEqual(old_view, (dest / '.workflow/CONTRACT.md').read_bytes())
            check = str(dest / 'tools/workflow/check-ref')
            self.assertEqual(subprocess.run([check, 'topic', 'fix/xy-1-test']).returncode, 0)
            self.assertNotEqual(subprocess.run([check, 'topic', 'fix/sg-1-test']).returncode, 0)
            (dest / '.workflow/grammar.sh').write_text('TOPIC_RE=.*\n')
            self.assertNotEqual(generate('--check').returncode, 0)

if __name__ == '__main__': unittest.main()
