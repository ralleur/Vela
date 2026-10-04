#!/usr/bin/env python3
"""Package only selected production inputs, reviewed exports and QA evidence."""
import json,zipfile,hashlib
from pathlib import Path
R=Path(__file__).resolve().parents[5];P=R/'marketing/video/shorts/vela-curated-v1';D=R/'build/launch/exports/vela-curated-v1';W=R/'build/launch/vela-curated-v1'
files=set()
for base in (P,D,W/'qa'):
 files.update(p for p in base.rglob('*') if p.is_file() and '__pycache__' not in p.parts)
for s in json.loads((P/'PROVENANCE.json').read_text())['sources']:
 p=R/s['path'];assert hashlib.sha256(p.read_bytes()).hexdigest()==s['sha256'];files.add(p)
files.add(R/'marketing/sources-and-licenses.md')
for r in json.loads((P/'editorial-validation.json').read_text())['clips']:
 assert hashlib.sha256((D/r['file']).read_bytes()).hexdigest()==r['sha256']
archive=D.parent/'vela-curated-v1-bundle.zip'
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=5) as z:
 for p in sorted(files):z.write(p,Path('Vela-Shorts-v1')/p.relative_to(R))
 z.writestr('Vela-Shorts-v1/START-HERE.txt',(P/'README.txt').read_text())
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None
 mp4s=[n for n in z.namelist() if '/exports/' in n and n.endswith('.mp4')];assert len(mp4s)==6
print(archive,archive.stat().st_size,'bytes;',len(files),'files; ZIP integrity passed')
