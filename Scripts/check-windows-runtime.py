#!/usr/bin/env python3
"""Check the actual NSIS payload, including app-local ONNX dependency closure."""
import os, pathlib, struct, subprocess, tempfile, shutil, sys, time
root = pathlib.Path(__file__).resolve().parent.parent
installers = [pathlib.Path(sys.argv[1])] if len(sys.argv)>1 else list((root/'Desktop/src-tauri/target/release/bundle/nsis').glob('*-setup.exe'))
sevenzip=shutil.which('7z') or shutil.which('7zz') or str(pathlib.Path(os.environ.get('ProgramFiles','C:/Program Files'))/'7-Zip/7z.exe')
if len(installers)!=1: raise SystemExit('Expected one NSIS installer')
def imports(binary):
    data=binary.read_bytes(); pe=struct.unpack_from('<I',data,0x3c)[0]
    if data[pe:pe+4]!=b'PE\0\0': raise ValueError('Invalid Windows binary: '+binary.name)
    machine,count,_,_,_,optional_size,_=struct.unpack_from('<HHIIIHH',data,pe+4)
    if machine!=0x8664: raise ValueError('Expected x64: '+binary.name)
    optional=pe+24
    if struct.unpack_from('<H',data,optional)[0]!=0x20b: raise ValueError('Expected PE32+')
    sections=[]
    for i in range(count):
        start=optional+optional_size+i*40
        size,address,raw_size,raw=struct.unpack_from('<IIII',data,start+8)
        sections.append((address,max(size,raw_size),raw))
    def offset(rva):
        for address,size,raw in sections:
            if address<=rva<address+size:return raw+rva-address
        raise ValueError('Invalid PE RVA')
    names=[]
    for index,stride,name_offset in [(1,20,12),(13,32,4)]: # regular + delay imports
        rva=struct.unpack_from('<I',data,optional+112+index*8)[0]
        if not rva: continue
        pos=offset(rva)
        while any(data[pos:pos+stride]):
            name_rva=struct.unpack_from('<I',data,pos+name_offset)[0]
            start=offset(name_rva);end=data.index(b'\0',start)
            names.append(data[start:end].decode('ascii'));pos+=stride
    return names
with tempfile.TemporaryDirectory(prefix='dictate-installer-check-') as folder:
    subprocess.run([sevenzip,'x','-y',f'-o{folder}',str(installers[0])],check=True,stdout=subprocess.DEVNULL)
    apps=list(pathlib.Path(folder).rglob('dictate-desktop.exe'))
    if len(apps)!=1: raise SystemExit('Installer is missing the app executable')
    app=apps[0]; payload=app.parent
    present={p.name.lower():p for p in payload.iterdir() if p.is_file()}
    for name in ['onnxruntime.dll','msvcp140.dll','vcruntime140.dll','license','third_party_licenses.txt','onnx-license']:
        if name not in present: raise SystemExit('Missing packaged runtime/notice: '+name)
    for binary in [app,*payload.glob('*.dll')]:
        required=imports(binary)
        missing=[name for name in required if name.lower().startswith(('msvcp','vcruntime','concrt','vcomp','onnxruntime')) and name.lower() not in present]
        if missing: raise SystemExit(binary.name+' requires missing app-local DLLs: '+', '.join(missing))
        print(binary.name+': '+', '.join(sorted(required)))
    if sys.platform=='win32':
        process=subprocess.Popen([str(app)],cwd=payload)
        try:
            time.sleep(8)
            if process.poll() is not None: raise SystemExit(f'Packaged app exited during startup: {process.returncode}')
            print('Extracted Windows app stayed running through its startup check.')
        finally:
            if process.poll() is None: process.terminate();process.wait(timeout=10)
    print('NSIS payload passed: x64, model runtime and notices present, no missing external MSVC runtime DLLs.')
