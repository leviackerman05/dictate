#!/usr/bin/env python3
"""Collect resolved upstream notices; run after cargo fetch and npm ci."""
import json, pathlib, subprocess
root = pathlib.Path(__file__).resolve().parent.parent
metadata = json.loads(subprocess.check_output(['cargo','metadata','--locked','--format-version','1','--manifest-path',str(root/'Desktop/src-tauri/Cargo.toml')]))
sections = ['Dictate portable app — resolved third-party license notices\n\nGenerated from Cargo.lock and installed npm dependencies. Upstream notices follow.']
for p in sorted(metadata['packages'], key=lambda p:(p['name'],p['version'])):
    if not p['source']: continue
    base = pathlib.Path(p['manifest_path']).parent
    files = sorted({f for glob in ('LICENSE*','LICENCE*','COPYING*','NOTICE*','UNLICENSE*','licenses/*','LICENSES/*') for f in base.glob(glob) if f.is_file()})
    if p.get('license_file') and (base/p['license_file']).is_file(): files.append(base/p['license_file'])
    sections.append(f"\n{'='*72}\n{p['name']} {p['version']}\nLicense: {p.get('license','See upstream')}\nSource: {p.get('repository') or p['source']}\n")
    for f in dict.fromkeys(files): sections.append(f'--- {f.relative_to(base)} ---\n'+f.read_text(errors='replace'))
# whisper-rs-sys includes native whisper.cpp/ggml with their own MIT notice.
for p in metadata['packages']:
    if p['name']=='whisper-rs-sys':
        base=pathlib.Path(p['manifest_path']).parent
        for f in sorted(base.glob('whisper.cpp/**/LICENSE*')):
            if f.is_file(): sections.append(f'\n--- {f.relative_to(base)} ---\n'+f.read_text(errors='replace'))
for module in ['@tauri-apps/api','@tauri-apps/plugin-dialog','lucide']:
    base=root/'Desktop/node_modules'/module
    for f in sorted(base.glob('LICENSE*')):
        if f.is_file(): sections.append(f'\n--- npm {module} ---\n'+f.read_text(errors='replace'))
(root/'Desktop/src-tauri/THIRD_PARTY_LICENSES.txt').write_text('\n'.join(line.rstrip() for line in '\n'.join(sections).splitlines())+'\n')
