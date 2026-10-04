#!/usr/bin/env python3
"""Export current kurtz screenshots; crop/resize real UI only, never repaint it."""
from pathlib import Path
from PIL import Image
import json,hashlib
R=Path(__file__).resolve().parents[2]; RAW=R/'build/rebrand-kurtz/captures'; WEB=R/'website/assets'; PUBLIC=R/'marketing/screenshots/kurtz-0.9.6'
PUBLIC.mkdir(parents=True,exist_ok=True)
SPECS={
 'player-clean':('player-clean-final.png',None),
 'player-controls':('player-controls-final.png',None),
 'local-workflow':('local-workflow-final.png',None),
 'jellyfin-home':('jellyfin-home-final.png',(0,0,823,363)),
 'jellyfin-detail':('jellyfin-detail-final.png',None),
 'subtitles':('subtitles-final.png',(3420,20,3840,450)),
}
manifest=[]
for key,(source,crop) in SPECS.items():
 p=RAW/source
 original=Image.open(p).convert('RGB');im=original.crop(crop) if crop else original
 im.save(PUBLIC/f'{key}.jpg',quality=93,optimize=True)
 widths=[min(768,im.width),im.width] if key.startswith('player-') else [im.width]
 for width in sorted(set(widths)):
  dest=im.resize((width,round(im.height*width/im.width)),Image.Resampling.LANCZOS) if width<im.width else im
  dest.save(WEB/(f'{key}-{width}.webp' if key.startswith('player-') else f'{key}.webp'),quality=87,method=6)
 if key=='jellyfin-home':im.crop((0,0,430,363)).save(WEB/'jellyfin-home-mobile.webp',quality=87,method=6)
 manifest.append({'id':key,'raw':str(p.relative_to(R)),'raw_size':original.size,'crop':crop,'export_size':im.size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'app':'kurtz 0.9.6 (8) Release, Mac Catalyst','date':'2026-10-04','kind':'actual application capture','notes':'Only openly licensed demo media; no personal library. Native menus retain platform selection colors.'})
(PUBLIC/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(f'Exported {len(manifest)} current app captures. Historical Vela captures are untouched.')
