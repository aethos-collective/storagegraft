#!/usr/bin/env python3
"""Trusted-base CI adapter. Treat event data as data; never execute PR content."""
import json
import os
import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[2]
event = json.loads(pathlib.Path(os.environ['GITHUB_EVENT_PATH']).read_text())
kind = os.environ['GITHUB_EVENT_NAME']
if kind == 'merge_group':
    raise SystemExit('Merge queue is not activated: constituent PR validation and check identity need live evidence. Do not validate synthetic queue refs as topics.')
if kind != 'pull_request_target':
    raise SystemExit('Unsupported trusted-check event: ' + kind)
pr = event['pull_request']
head = pr['head']['ref']
base = pr['base']['ref']
for mode, name in [('topic', head), ('target', base)]:
    if not isinstance(name, str):
        raise SystemExit('Missing ref metadata')
    subprocess.run([str(root / 'tools/workflow/check-ref'), mode, name], check=True)
print('Validated PR head.ref and base.ref using trusted-base policy.')
