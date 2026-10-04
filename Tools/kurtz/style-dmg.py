#!/usr/bin/env python3
"""Write the kurtz Finder layout inside an already-mounted installer volume.

Install Tools/kurtz/dmg-requirements.txt in a build-only Python environment.
Uses ds_store/mac_alias, following dmgbuild's documented Finder metadata format.
No Finder automation or change to the app's signed contents is needed.
"""
import argparse
import shutil
import subprocess
from pathlib import Path

from ds_store import DSStore
from mac_alias import Alias, Bookmark

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('volume', type=Path)
parser.add_argument('--work', type=Path, required=True)
args = parser.parse_args()
volume = args.volume.resolve()
args.work.mkdir(parents=True, exist_ok=True)

# Both image representations occupy 768 x 512 Finder points. The 2x original
# stays intact; sips/tiffutil only produce display-resolution representations.
original = ROOT / 'marketing/dmg/background@2x.png'
small = args.work / 'background.png'
background = volume / '.background.tiff'
subprocess.run(['sips', '-z', '512', '768', str(original), '--out', str(small)], check=True)
subprocess.run(['tiffutil', '-cathidpicheck', str(small), str(original), '-out', str(background)], check=True)

icon = volume / 'kurtz.app/Contents/Resources/AppIcon-kurtz.icns'
shutil.copy2(icon, volume / '.VolumeIcon.icns')
subprocess.run(['xcrun', 'SetFile', '-a', 'C', str(volume)], check=True)

window = {
    'WindowBounds': '{{180, 140}, {768, 512}}',
    'ShowStatusBar': False, 'ShowTabView': False, 'ShowToolbar': False,
    'ShowPathbar': False, 'ShowSidebar': False, 'ContainerShowSidebar': False,
    'PreviewPaneVisibility': False, 'SidebarWidth': 0,
}
icons = {
    'viewOptionsVersion': 1, 'backgroundType': 2,
    'backgroundColorRed': 0.122, 'backgroundColorGreen': 0.122,
    'backgroundColorBlue': 0.122,
    'backgroundImageAlias': Alias.for_file(str(background)).to_bytes(),
    'gridOffsetX': 0.0, 'gridOffsetY': 0.0, 'gridSpacing': 99.0,
    'arrangeBy': 'none', 'showIconPreview': True, 'showItemInfo': False,
    'labelOnBottom': True, 'textSize': 14.0, 'iconSize': 112.0,
    'scrollPositionX': 0.0, 'scrollPositionY': 0.0,
}
with DSStore.open(str(volume / '.DS_Store'), 'w+') as store:
    store['.']['vSrn'] = ('long', 1)
    store['.']['bwsp'] = window
    store['.']['icvp'] = icons
    store['.']['pBBk'] = Bookmark.for_file(str(background))
    store['.']['icvl'] = ('type', b'icnv')
    store['kurtz.app']['Iloc'] = (244, 216)
    store['Applications']['Iloc'] = (524, 216)

visible = sorted(p.name for p in volume.iterdir() if not p.name.startswith('.'))
assert visible == ['Applications', 'kurtz.app'], visible
print('kurtz installer layout: 768x512 points; two visible items; Retina background')
