#!/usr/bin/env python3
"""Fail if Git contains prohibited binary/private/workspace artifacts. Never prints file contents."""
from pathlib import Path
import subprocess
import sys
files = subprocess.check_output(['git', 'ls-files', '-z']).decode().split('\0')
forbidden = {'.nsp', '.xci', '.nsz', '.nca', '.keys', '.key', '.pem', '.sav', '.srm', '.zip', '.log'}
bad = []
for name in filter(None, files):
    path = Path(name)
    if path.suffix.lower() in forbidden or any(part.lower() in {'build', '.build', 'firmware', 'saves', 'userlibrary', 'portablelibrary', 'diagnostics', 'revisions', 'packages', 'staging'} or part.lower().endswith(('.app', '.zmslibrary')) for part in path.parts):
        bad.append(name)
    elif path.is_file() and path.suffix in {'.swift', '.py', '.md', '.json', '.plist', '.sh', '.c', '.h'}:
        data = path.read_bytes()
        if b'-----BEGIN ' + b'PRIVATE KEY-----' in data or b'-----BEGIN ' + b'RSA PRIVATE KEY-----' in data:
            bad.append(name)
if bad:
    print(f'FAIL: {len(bad)} prohibited tracked artifact(s); inspect Git locally.')
    sys.exit(1)
print(f'PASS: {len(list(filter(None, files)))} tracked files; no prohibited artifacts or private-key blocks.')
