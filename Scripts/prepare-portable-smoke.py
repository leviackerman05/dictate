#!/usr/bin/env python3
"""Prepare public model + synthetic PCM for an explicitly requested smoke test."""
import hashlib, os, pathlib, shutil, urllib.request
root = pathlib.Path(__file__).resolve().parent.parent
dest = pathlib.Path(os.environ['DICTATE_SMOKE_DIR'])
(dest/'models').mkdir(parents=True, exist_ok=True)
model = dest/'models/ggml-tiny.bin'
expected = 'be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21'
class HTTPSRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if not newurl.startswith('https://'): raise ValueError('Non-HTTPS redirect rejected')
        return super().redirect_request(req, fp, code, msg, headers, newurl)
if not model.exists():
    opener=urllib.request.build_opener(HTTPSRedirect())
    with opener.open('https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-tiny.bin', timeout=120) as response, model.open('wb') as out:
        shutil.copyfileobj(response,out)
if hashlib.sha256(model.read_bytes()).hexdigest()!=expected:
    raise SystemExit('Model checksum failed; remove the test download and retry')
parakeet = dest/'models/parakeet'
parakeet.mkdir(exist_ok=True)
for name, expected in [
    ('encoder-model.int8.onnx','6139d2fa7e1b086097b277c7149725edbab89cc7c7ae64b23c741be4055aff09'),
    ('decoder_joint-model.int8.onnx','eea7483ee3d1a30375daedc8ed83e3960c91b098812127a0d99d1c8977667a70'),
    ('vocab.txt','d58544679ea4bc6ac563d1f545eb7d474bd6cfa467f0a6e2c1dc1c7d37e3c35d')]:
    file = parakeet/name
    if not file.exists():
        with urllib.request.build_opener(HTTPSRedirect()).open('https://huggingface.co/istupakov/parakeet-tdt-0.6b-v3-onnx/resolve/8f23f0c03c8761650bdb5b40aaf3e40d2c15f1ce/'+name, timeout=180) as response, file.open('wb') as out:
            shutil.copyfileobj(response,out)
    with file.open('rb') as source:
        digest=hashlib.file_digest(source,'sha256').hexdigest()
    if digest!=expected: raise SystemExit('Parakeet checksum failed: '+name)
shutil.copyfile(root/'Tests/Fixtures/synthetic-speech.f32',dest/'synthetic.f32')
print('Verified Whisper Tiny and Parakeet models and synthetic PCM fixture; no microphone or paid service used.')
