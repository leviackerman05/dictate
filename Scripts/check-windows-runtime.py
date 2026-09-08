#!/usr/bin/env python3
"""Inspect the actual NSIS payload; reject non-system C/C++ runtime DLL imports."""
import os, pathlib, struct, subprocess, tempfile, shutil, sys
root = pathlib.Path(__file__).resolve().parent.parent
installers = [pathlib.Path(sys.argv[1])] if len(sys.argv)>1 else list((root/'Desktop/src-tauri/target/release/bundle/nsis').glob('*-setup.exe'))
sevenzip=shutil.which('7z') or shutil.which('7zz') or str(pathlib.Path(os.environ.get('ProgramFiles','C:/Program Files'))/'7-Zip/7z.exe')
if len(installers)!=1: raise SystemExit('Expected one NSIS installer')
with tempfile.TemporaryDirectory(prefix='dictate-installer-check-') as folder:
    subprocess.run([sevenzip,'x','-y',f'-o{folder}',str(installers[0])],check=True,stdout=subprocess.DEVNULL)
    binaries=list(pathlib.Path(folder).rglob('dictate-desktop.exe'))
    if len(binaries)!=1: raise SystemExit('Installer is missing the app executable')
    data=binaries[0].read_bytes()
    pe=struct.unpack_from('<I',data,0x3c)[0]
    if data[pe:pe+4]!=b'PE\0\0': raise SystemExit('Invalid Windows executable')
    machine,count,_,_,_,optional_size,_=struct.unpack_from('<HHIIIHH',data,pe+4)
    if machine!=0x8664: raise SystemExit('Expected x64 Windows app')
    optional=pe+24
    if struct.unpack_from('<H',data,optional)[0]!=0x20b: raise SystemExit('Expected PE32+')
    import_rva=struct.unpack_from('<I',data,optional+112+8)[0]
    sections=[]
    for i in range(count):
        offset=optional+optional_size+i*40
        virtual_size,virtual_address,raw_size,raw_offset=struct.unpack_from('<IIII',data,offset+8)
        sections.append((virtual_address,max(virtual_size,raw_size),raw_offset))
    def offset(rva):
        for address,size,raw in sections:
            if address<=rva<address+size:return raw+rva-address
        raise ValueError('Invalid PE RVA')
    imports=[]
    pos=offset(import_rva)
    while any(data[pos:pos+20]):
        name_rva=struct.unpack_from('<I',data,pos+12)[0]
        start=offset(name_rva);end=data.index(b'\0',start)
        imports.append(data[start:end].decode('ascii'));pos+=20
    forbidden=[name for name in imports if name.lower().startswith(('msvcp','vcruntime','concrt'))]
    if forbidden: raise SystemExit('Installer still requires external C/C++ runtime: '+', '.join(forbidden))
    for file in ['LICENSE','THIRD_PARTY_LICENSES.txt']:
        if not (pathlib.Path(folder)/file).is_file():raise SystemExit('Missing packaged notice: '+file)
    print('Windows NSIS payload: x64 executable, notices present, no external MSVC runtime DLLs.')
    print('Imports: '+', '.join(sorted(imports)))
