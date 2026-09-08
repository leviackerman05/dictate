#!/usr/bin/env python3
"""Create an installer manifest only from final, present release artifacts."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent
version = (root / 'Release/version.txt').read_text().strip()
artifacts = {
    'macArm64': ('Dictate.dmg', 'macOS 14+', 'Apple silicon', 'community'),
    'windowsX64': ('Dictate-Windows-x64-setup.exe', 'Windows 10/11', 'x64', 'beta'),
}
manifest = {'schemaVersion': 1, 'version': version}
for key, (name, system, architecture, channel) in artifacts.items():
    path = root / 'dist' / name
    if not path.is_file():
        raise SystemExit(f'Missing release artifact: {name}')
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    manifest[key] = dict(asset=name, os=system, architecture=architecture,
                         channel=channel, sha256=digest, bytes=path.stat().st_size)
    path.with_name(name + '.sha256').write_text(f'{digest}  {name}\n')
(root / 'dist/manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(f'Validated {len(artifacts)} release artifacts for {version}')
