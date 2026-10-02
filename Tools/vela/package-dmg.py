#!/usr/bin/env python3
"""Package a signed Vela app in a Retina, drag-to-Applications installer.

Run with the Python environment containing dmg-requirements.txt. Production
requires Developer ID signing and a stapled notarization ticket. The signed app
contents are never modified. --revision distinguishes packaging-only updates.
"""
from pathlib import Path
import argparse
import hashlib
import json
import plistlib
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('app', type=Path)
parser.add_argument('--output', type=Path, default=Path('build/release'))
parser.add_argument('--revision', type=int, default=1)
parser.add_argument('--development-preview', action='store_true')
a = parser.parse_args()
assert a.revision > 0, 'Packaging revision must be positive'
# Fail before creating a volume if the build-only dependencies are missing.
import ds_store  # noqa: E402,F401
import mac_alias  # noqa: E402,F401

app = a.app.resolve()
out = a.output.resolve()
out.mkdir(parents=True, exist_ok=True)
info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
version = info['CFBundleShortVersionString']
assert info['CFBundleIdentifier'] == 'com.ralleur.vela.mac', 'Unexpected app identity'
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
signature = subprocess.run(['codesign', '-dvv', str(app)], capture_output=True, text=True, check=True).stderr
binary = app / 'Contents/MacOS' / info['CFBundleExecutable']
archs = subprocess.check_output(['lipo', '-archs', str(binary)], text=True).split()
assert {'arm64', 'x86_64'}.issubset(archs), 'Release must include both Mac architectures'
if not a.development_preview:
    assert 'Authority=Developer ID Application:' in signature, 'Public DMG requires Developer ID signing'
    subprocess.run(['xcrun', 'stapler', 'validate', str(app)], check=True)
    subprocess.run(['spctl', '--assess', '--type', 'execute', '--verbose=2', str(app)], check=True)

revision = f'-r{a.revision}' if a.revision > 1 else ''
suffix = '-DEVELOPMENT-ONLY' if a.development_preview else ''
name = f'Vela-{version}-macOS-universal{revision}{suffix}'
work = out / (name + '-work')
dmg = out / (name + '.dmg')
if work.exists() or dmg.exists():
    raise SystemExit(f'Refusing to overwrite existing work/image for {name}')
work.mkdir()
modern = subprocess.run(['diskutil', 'image', 'create', 'blank', '--help'], capture_output=True).returncode == 0
writable = work / ('installer.asif' if modern else 'installer-rw.dmg')
# Room for the current universal app, APFS metadata and installer artwork.
app_bytes = sum(p.stat().st_size for p in app.rglob('*') if p.is_file())
size_mb = max(768, (app_bytes * 2 // (1024 * 1024)) + 128)
if modern:
    create = ['diskutil', 'image', 'create', 'blank', '--format', 'ASIF', '--size', f'{size_mb}M', '--volumeName', 'Vela', '--fs', 'APFS', str(writable)]
else:
    create = ['hdiutil', 'create', '-size', f'{size_mb}m', '-fs', 'APFS', '-volname', 'Vela', '-type', 'UDRW', str(writable)]
subprocess.run(create, check=True)
mount = work / 'mounted'
attach = (['diskutil', 'image', 'attach', '--plist', '--nobrowse', '--mountPoint', str(mount), str(writable)] if modern else ['hdiutil', 'attach', '-plist', '-nobrowse', '-mountpoint', str(mount), str(writable)])
attached = plistlib.loads(subprocess.check_output(attach))
mounts = [e for e in attached['system-entities'] if e.get('mount-point')]
assert len(mounts) == 1, 'Expected one installer volume'
volume = Path(mounts[0]['mount-point'])
assert volume.resolve() == mount.resolve(), 'Unexpected mount location'
try:
    subprocess.run(['ditto', str(app), str(volume / 'Vela.app')], check=True)
    (volume / 'Applications').symlink_to('/Applications', target_is_directory=True)
    # The app already exposes its notices in Settings. Retain complete release
    # source/license records on the image without adding visible Finder clutter.
    licenses = volume / '.licenses'
    licenses.mkdir()
    shutil.copy2(ROOT / 'Shared/Resources/VelaThirdPartyNotices.txt', licenses / 'Open Source Notices.txt')
    shutil.copy2(ROOT / 'LICENSE.md', licenses / 'Vela Source License.txt')
    shutil.copytree(ROOT / 'docs/release', licenses / 'release')
    (licenses / 'README.txt').write_text(
        f'Vela {version}, build {info["CFBundleVersion"]}; packaging revision {a.revision}.\n'
        'Drag Vela.app to Applications. Open Source Notices are also in Vela Settings.\n'
        f'Source, license record and downloads: https://github.com/ralleur/Vela/releases/tag/vela-{version}\n'
        'The application signature and notarization ticket are preserved.\n'
        + ('DEVELOPMENT-ONLY: registered test Macs only; not a public installer.\n' if a.development_preview else '')
    )
    subprocess.run([sys.executable, str(ROOT / 'Tools/vela/style-dmg.py'), str(volume), '--work', str(work)], check=True)
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(volume / 'Vela.app')], check=True)
    subprocess.run(['sync'], check=True)
finally:
    # Only this freshly-created build volume is eligible for forced detach.
    # macOS Virtualization can hold a read-only reference to removable volumes.
    detached = subprocess.run(['hdiutil', 'detach', str(volume)])
    if detached.returncode:
        subprocess.run(['hdiutil', 'detach', '-force', str(volume)], check=True)

convert = (['diskutil', 'image', 'create', 'from', '--format', 'UDZO', str(writable), str(dmg)] if modern else ['hdiutil', 'convert', str(writable), '-format', 'UDZO', '-o', str(dmg)])
subprocess.run(convert, check=True)
subprocess.run(['hdiutil', 'verify', str(dmg)], check=True)
sha = hashlib.sha256(dmg.read_bytes()).hexdigest()
dmg.with_suffix('.dmg.sha256').write_text(f'{sha}  {dmg.name}\n')
manifest = {
    'file': dmg.name, 'sha256': sha, 'version': version,
    'build': info['CFBundleVersion'], 'packaging_revision': a.revision,
    'architectures': archs, 'minimum_macos': info.get('LSMinimumSystemVersion'),
    'development_only': a.development_preview, 'size': dmg.stat().st_size,
    'window_points': [768, 512], 'visible_items': ['Vela.app', 'Applications'],
    'background_sha256': hashlib.sha256((ROOT / 'marketing/dmg/background@2x.png').read_bytes()).hexdigest(),
}
dmg.with_suffix('.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(json.dumps(manifest, indent=2))
