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
    with opener.open('https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin', timeout=120) as response, model.open('wb') as out:
        shutil.copyfileobj(response,out)
if hashlib.sha256(model.read_bytes()).hexdigest()!=expected:
    raise SystemExit('Model checksum failed; remove the test download and retry')
shutil.copyfile(root/'Tests/Fixtures/synthetic-speech.f32',dest/'synthetic.f32')
print('Verified tiny model and synthetic PCM fixture; no microphone or paid service used.')
