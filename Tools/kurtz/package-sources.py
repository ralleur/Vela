#!/usr/bin/env python3
"""Bundle a committed application tree and hash-verified pinned dependency sources."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--ref', default='HEAD')
p.add_argument('--version', required=True)
p.add_argument('--output', type=Path, default=ROOT / 'build/release')
a = p.parse_args()
commit = subprocess.check_output(['git', 'rev-parse', a.ref + '^{commit}'], cwd=ROOT, text=True).strip()
index_bytes = subprocess.check_output(['git', 'show', f'{commit}:docs/release/source-index.json'], cwd=ROOT)
index = json.loads(index_bytes)
inputs = ROOT / 'build/release/source-inputs'
for item in index:
    source = inputs / item['archive']
    assert source.parent == inputs and source.is_file(), 'Missing or invalid source archive'
    assert hashlib.sha256(source.read_bytes()).hexdigest() == item['sha256'], source.name
name = f'kurtz-{a.version}-sources'
a.output.mkdir(parents=True, exist_ok=True)
output = a.output / (name + '.tar.gz')
if output.exists():
    raise SystemExit('Refusing to overwrite existing source delivery')
with tempfile.TemporaryDirectory(prefix='kurtz-sources-') as tmp:
    application = Path(tmp) / 'application.tar'
    with application.open('wb') as stream:
        subprocess.run(['git', 'archive', '--format=tar', commit], cwd=ROOT, stdout=stream, check=True)
    record = Path(tmp) / 'README.txt'
    record.write_text(
        f'kurtz {a.version}\nApplication commit: {commit}\n\n'
        'application.tar is the complete committed application tree, including fonts,\n'
        'notices, build/install tools, engine-source records and the release guide.\n'
        'Extract it, then follow docs/BUILDING.md and docs/release/README.md.\n'
        'dependencies/ contains the pinned source/build-recipe archives named in\n'
        'source-index.json; every archive digest was verified before packaging.\n'
        'Component recipes identify further upstream source inputs and patches.\n'
        'Apple SDKs/Xcode and your own signing identity are external prerequisites.\n'
        'No signing keys, private configuration or downloaded media are included.\n'
    )
    index_file = Path(tmp) / 'source-index.json'
    index_file.write_bytes(index_bytes)
    def normalize(info):
        info.uid = info.gid = 0
        info.uname = info.gname = ''
        return info
    with tarfile.open(output, 'w:gz', compresslevel=1) as tar:
        for file in [application, record, index_file]:
            tar.add(file, arcname=f'{name}/{file.name}', filter=normalize)
        for item in index:
            tar.add(inputs / item['archive'], arcname=f'{name}/dependencies/{item["archive"]}', filter=normalize)
sha = hashlib.sha256(output.read_bytes()).hexdigest()
output.with_suffix(output.suffix + '.sha256').write_text(f'{sha}  {output.name}\n')
print(json.dumps({'file': str(output), 'commit': commit, 'dependency_archives': len(index), 'sha256': sha}))
