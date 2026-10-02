#!/usr/bin/env python3
"""Collect checked-out package notices without downloading or changing dependencies.

Run after resolving the Mac workspace. The output is bundled for offline access.
Binary-engine source/compliance review remains a separate distribution requirement.
"""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
checkouts = root / 'build/dd-mac/SourcePackages/checkouts'
if not checkouts.is_dir():
    raise SystemExit('Resolve/build Vela.xcworkspace first; package checkouts are missing.')
resolved = root / 'Swiftfin.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'
pins = {p['identity'].lower(): p for p in json.loads(resolved.read_text())['pins']}
parts = ['Vela - Open Source Notices\n\nVela is based on Swiftfin (MPL-2.0). Thank you to the contributors of the projects below.\n\nThis inventory preserves license text from the resolved source packages. It is not an assertion that binary distribution obligations have been completed. libVLC and libmpv also contain third-party components. See VELA.md for distribution requirements.\n']
parts += ['Vela / Swiftfin\n' + (root / 'LICENSE.md').read_text()]
packages = sorted(checkouts.iterdir()) + [root / 'build/mac-packages/MPVUI', root / 'build/mac-packages/BlurHashKit']
seen = set()
for package in packages:
    identity = package.name.lower()
    if identity in seen or not package.is_dir():
        continue
    seen.add(identity)
    pin = pins.get(identity, {})
    info = pin.get('location', '') + '\n' + json.dumps(pin.get('state', {}), sort_keys=True)
    notices = [p for p in package.iterdir() if p.is_file() and p.name.split('.')[0].upper() in {'LICENSE', 'COPYING', 'NOTICE'}]
    for notice in sorted(notices):
        parts.append(package.name + '\n' + info + '\n' + notice.name + '\n\n' + notice.read_text(errors='replace'))
for name in ['Shared/Resources/Fonts/NotoSansCJK-OFL.txt', 'build/mac-packages/MPVUI/Libmpv.xcframework/RECIPE_LICENSE']:
    p = root / name
    if p.exists():
        parts.append(name + '\n\n' + p.read_text())
output = root / 'Shared/Resources/VelaThirdPartyNotices.txt'
output.write_text(('\n\n' + '=' * 72 + '\n\n').join(parts))
print(f'Collected {len(parts) - 1} notice sections into {output.relative_to(root)}')
