#!/usr/bin/env python3
"""Export real app captures. Crops only; never composite or repaint app UI."""
from pathlib import Path
from PIL import Image,ImageOps,ImageDraw,ImageFont
import json,hashlib
R=Path(__file__).resolve().parents[2]; RAW=R/'build/launch/raw'; WEB=R/'website/assets'; PUBLIC=R/'marketing/screenshots/macos'; BRAND=R/'marketing/brand'
for p in (WEB,PUBLIC,BRAND):p.mkdir(parents=True,exist_ok=True)
# The system capture badge occupies the outer title strip in library captures.
# That strip is excluded as a rectangular crop, not painted out.
SPECS={
 'player-clean':('player-clean-retina.png',None),
 'player-controls':('player-controls-native.png',None),
 'local-workflow':('local-workflow.png',(0,52,880,500)),
 'jellyfin-home':('jellyfin-home.png',(0,48,823,803)),
 'jellyfin-detail':('jellyfin-detail.png',(0,48,823,803)),
 'subtitles':('subtitles-full.png',(3040,58,3840,700)),
 'fullscreen':('fullscreen-final.png',None),
 'mac-window':('player-clean-retina.png',None),
}
manifest=[]
for key,(source,crop) in SPECS.items():
 p=RAW/source
 if not p.exists():continue
 original=Image.open(p).convert('RGB');im=original.crop(crop) if crop else original
 im.save(PUBLIC/f'{key}.jpg',quality=93,optimize=True)
 for width in ([768,1366] if key.startswith('player-') else [min(im.width,1366)]):
  dest=im.resize((width,round(im.height*width/im.width)),Image.Resampling.LANCZOS) if width<im.width else im
  dest.save(WEB/(f'{key}-{width}.webp' if key.startswith('player-') else f'{key}.webp'),quality=84,method=6)
 if key=='jellyfin-home':
  # Real content crop, not a different UI. Keeps Continue and the movie row legible.
  im.crop((0,0,430,min(im.height,610))).save(WEB/'jellyfin-home-mobile.webp',quality=87,method=6)
 manifest.append({'id':key,'raw':str(p.relative_to(R)),'raw_size':original.size,'crop':crop,'export_size':im.size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'app':'Vela 0.9.4 (5)','date':'2026-10-02','kind':'real application capture','source_phase':('initial-build.json' if key in ('player-clean','player-controls','mac-window') else 'build.json' if key in ('jellyfin-home','subtitles','fullscreen') else 'intermediate: account-menu fix present; before tab-bar fix'),'derivatives':({'jellyfin-home-mobile.webp':{'crop':[0,0,430,min(im.height,610)]}} if key=='jellyfin-home' else {})})
glyph=Image.open(R/'Swiftfin/Vela/AppIcon-vela.icon/Assets/Glyph.png').convert('RGBA')
icon=Image.new('RGBA',glyph.size,'#11151e');icon.alpha_composite(glyph)
icon.convert('RGB').resize((256,256),Image.Resampling.LANCZOS).save(BRAND/'vela-icon.png')
icon.convert('RGB').resize((128,128),Image.Resampling.LANCZOS).save(WEB/'vela-icon.png')
# Social card is explicitly a typographic composition, not an app mock-up.
FONT='/System/Library/Fonts/Supplemental/Arial.ttf';BOLD='/System/Library/Fonts/Supplemental/Arial Bold.ttf'
card=Image.new('RGB',(1200,630),'#11151e');draw=ImageDraw.Draw(card)
card.paste(icon.convert('RGB').resize((80,80)),(48,36));draw.text((143,59),'Vela',font=ImageFont.truetype(BOLD,32),fill='white')
draw.text((54,161),'Just watch\nthe video.',font=ImageFont.truetype(BOLD,69),fill='#f3f5f9',spacing=0)
draw.text((57,354),'Your files. Your Jellyfin library.',font=ImageFont.truetype(FONT,23),fill='#aeb7c6')
draw.text((57,388),'One Mac player. Free & open source.',font=ImageFont.truetype(FONT,23),fill='#aeb7c6')
hero=Image.open(PUBLIC/'player-clean.jpg');hero=ImageOps.fit(hero,(566,380),centering=(.65,.5));card.paste(hero,(620,122))
draw.text((57,529),'0.9.4 BETA · macOS 15.6+',font=ImageFont.truetype(BOLD,18),fill='#80aaff')
draw.text((57,588),'Sintel © Blender Foundation / durian.blender.org · CC BY 3.0',font=ImageFont.truetype(FONT,14),fill='#aeb7c6')
card.save(WEB/'social-preview.jpg',quality=91,optimize=True);card.save(R/'marketing/thumbnails/social-preview.jpg',quality=94)
(R/'marketing/screenshots/manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(f'Exported {len(manifest)} capture assets')
