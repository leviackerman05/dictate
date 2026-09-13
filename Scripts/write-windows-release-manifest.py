#!/usr/bin/env python3
"""Create the Windows-only release manifest from the final installer."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent
version = (root / 'Release/windows-version.txt').read_text().strip()
name = 'Dictate-Windows-x64-setup.exe'
path = root / 'dist' / name
if not path.is_file():
    raise SystemExit(f'Missing release artifact: {name}')
digest = hashlib.sha256(path.read_bytes()).hexdigest()
manifest = {
    'schemaVersion': 1,
    'version': version,
    'windowsX64': {
        'asset': name,
        'os': 'Windows 10/11',
        'architecture': 'x64',
        'channel': 'beta',
        'sha256': digest,
        'bytes': path.stat().st_size,
    },
}
path.with_name(name + '.sha256').write_text(f'{digest}  {name}\n')
(root / 'dist/manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(f'Validated the Windows release artifact for {version}')
