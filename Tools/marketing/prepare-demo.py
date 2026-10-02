#!/usr/bin/env python3
"""Make real Jellyfin media folders from licensed local masters; needs Pillow/ffmpeg.
Keep masters in ignored build/launch/media. This does not touch a personal server.
"""
from pathlib import Path
import subprocess, os
from PIL import Image, ImageOps, ImageDraw, ImageFont
ROOT = Path(__file__).resolve().parents[2]
MEDIA = ROOT / 'build/launch/media'
LIBRARY = ROOT / 'build/launch/library'
MOVIES = [
 ('Big Buck Bunny', 2008, 'bbb_sunflower_1080p_30fps_normal.mp4', 100, 'A quiet day in the meadow takes an unexpected turn. An open movie from the Blender Foundation.'),
 ('Sintel', 2010, 'Sintel.mkv', 330, 'A young traveller follows a small dragon into a much larger world. An open movie directed by Colin Levy.'),
 ('Caminandes: Gran Dillama', 2013, 'caminandes_gran_dillama.mp4', 55, 'One determined llama. One very tempting patch of grass. An open short by Pablo Vazquez and the Caminandes team.'),
]
FONT = '/System/Library/Fonts/Supplemental/Arial Bold.ttf'
for title, year, source, frame, plot in MOVIES:
 d=LIBRARY / f'{title.replace(":", " —")} ({year})'; d.mkdir(parents=True,exist_ok=True)
 dest=d / (title.replace(':','')+Path(source).suffix)
 if not dest.exists(): os.link(MEDIA/source,dest)
 subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-ss',str(frame),'-i',str(dest),'-frames:v','1',str(d/'backdrop.jpg')],check=True)
 im=ImageOps.fit(Image.open(d/'backdrop.jpg'),(800,1200),centering=(.55,.5)).convert('RGBA')
 grad=Image.new('RGBA',im.size); px=grad.load()
 for y in range(1200):
  alpha=round(235*max(0,(y-470)/730))
  for x in range(800): px[x,y]=(9,14,22,alpha)
 im=Image.alpha_composite(im,grad); draw=ImageDraw.Draw(im)
 draw.text((56,850),'BLENDER OPEN MOVIE',font=ImageFont.truetype(FONT,22),fill='#ffffff')
 lines={'Big Buck Bunny':['BIG BUCK','BUNNY'],'Sintel':['SINTEL'],'Caminandes: Gran Dillama':['CAMINANDES','Gran Dillama']}[title]
 for i,line in enumerate(lines): draw.text((52,900+i*72),line,font=ImageFont.truetype(FONT,64 if len(line)<12 else 54),fill='#ffffff')
 draw.text((56,1110),str(year),font=ImageFont.truetype(FONT,24),fill='#c3cbd6')
 im.convert('RGB').save(d/'poster.jpg',quality=94)
 (d/'movie.nfo').write_text(f'<?xml version="1.0" encoding="utf-8"?><movie><title>{title}</title><year>{year}</year><plot>{plot}</plot><genre>Animation</genre><studio>Blender Foundation</studio><lockdata>true</lockdata></movie>')
print(f'Prepared {len(MOVIES)} films in {LIBRARY}')
