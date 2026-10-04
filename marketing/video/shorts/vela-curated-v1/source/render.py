#!/usr/bin/env python3
"""Reproducible Vela renderer: real captures + editorial typography, no painted app UI."""
import json, subprocess, sys, shutil, math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
R=Path(__file__).resolve().parents[5];P=R/'marketing/video/shorts/vela-curated-v1'
W=R/'build/launch/vela-curated-v1';D=R/'build/launch/exports/vela-curated-v1'
S=json.loads((P/'series.json').read_text());(W/'render').mkdir(parents=True,exist_ok=True)
FONT='/System/Library/Fonts/Supplemental/Arial.ttf';BOLD='/System/Library/Fonts/Supplemental/Arial Bold.ttf'
BG='#0d1118';INK='#f3f5f9';BLUE='#80aaff';MUTED='#aeb7c6'
logo=Image.open(P/'assets/vela-wordmark.png')
def font(n,bold=False):return ImageFont.truetype(BOLD if bold else FONT,n)
def run(a):subprocess.run(a,check=True)
def canvas(s,path):
 im=Image.new('RGB',(1080,1920),BG);d=ImageDraw.Draw(im)
 # Restrained Vela blue illumination, rendered as native graphic background.
 for y in range(1920):
  q=math.exp(-((y-1000)/630)**2)
  d.line((0,y,1079,y),fill=(int(13+q*3),int(17+q*6),int(24+q*11)))
 if s.get('visual')=='endcard':
  l=logo.resize((490,171),Image.Resampling.LANCZOS);im.paste(l,(254,710),l)
  d.text((498,980),'Discover Vela',font=font(60,True),fill=INK,anchor='mm')
  d.text((498,1170),'ralleur.github.io/Vela',font=font(39),fill=BLUE,anchor='mm')
 else:
  d.text((78,204),'VELA  /  FOR MAC',font=font(27,True),fill=BLUE)
  size=92
  while max(d.textlength(t,font=font(size,True)) for t in s['lines'])>844:size-=1
  for i,t in enumerate(s['lines']):d.text((72,302+i*(size+8)),t,font=font(size,True),fill=BLUE if i==len(s['lines'])-1 else INK)
  if s.get('detail'):
   d.text((78,1105),s.get('detail_label','PLAYER DETAIL'),font=font(23,True),fill=MUTED)
  if s.get('quote'):
   q=s['quote']
   for i,t in enumerate(q[:2]):d.text((78,1135+i*60),t,font=font(49),fill=INK)
   d.text((78,1275),q[2],font=font(29),fill=MUTED)
  l=logo.resize((145,51),Image.Resampling.LANCZOS);im.paste(l,(78,1420),l)
  note=s.get('note','Real Vela capture')
  # Short scope note stays in the conservative safe area.
  size=24
  while d.textlength(note,font=font(size))>660:size-=1
  d.text((252,1445),note,font=font(size),fill=MUTED,anchor='lm')
 im.save(path)
def render_shot(item,j,s):
 p=W/'render'/f'{item["id"]}-{j}.mp4';bg=p.with_suffix('.png');canvas(s,bg)
 common=['-r','30','-an','-c:v','libx264','-crf','17','-preset','fast','-threads','2','-pix_fmt','yuv420p','-colorspace','bt709','-color_trc','bt709','-color_primaries','bt709','-color_range','tv','-frames:v',str(round(s['seconds']*30))]
 if s.get('visual')=='endcard':
  run(['ffmpeg','-y','-v','error','-loop','1','-framerate','30','-i',str(bg),'-vf','scale=out_color_matrix=bt709:out_range=tv,setsar=1']+common+[str(p)]);return p
 still=s.get('visual')=='still';src=R/s['source'];hold=s.get('hold',0)
 inp=['-loop','1','-framerate','30'] if still else ['-ss',str(s['source_in'])]
 args=['ffmpeg','-y','-v','error']+inp+['-i',str(src),'-loop','1','-framerate','30','-i',str(bg)]
 crop=s.get('crop');cropstr=f'crop={crop[2]}:{crop[3]}:{crop[0]}:{crop[1]},' if crop else ''
 # The result hold is explicit, never a replacement for an absent interaction.
 prefix=f'fps=30,trim=duration={s["seconds"]-hold},setpts=PTS-STARTPTS'
 if hold:prefix+=f',tpad=stop_mode=clone:stop_duration={hold}'
 detail=s.get('detail')
 flt=f'[0:v]{prefix},split=2[whole][focus];' if detail else f'[0:v]{prefix}[whole];'
 if still:
  flt+='[whole]scale=850:760:force_original_aspect_ratio=decrease:out_color_matrix=bt709:out_range=tv,pad=850:760:(ow-iw)/2:(oh-ih)/2:color=0x10151e,setsar=1[pic];[1:v][pic]overlay=72:580:shortest=1[out]'
 else:
  flt+=f'[whole]{cropstr}scale=850:496:force_original_aspect_ratio=decrease:out_color_matrix=bt709:out_range=tv,pad=850:496:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1[pic];[1:v][pic]overlay=72:585:shortest=1'+('[base];' if detail else '[out]')
 if detail:
  x,y,w,h=detail;height=round(850*h/w/2)*2
  flt+=f'[focus]crop={w}:{h}:{x}:{y},scale=850:{height}:out_color_matrix=bt709:out_range=tv,setsar=1[zoom];[base][zoom]overlay=72:1155:shortest=1[out]'
 flt+=';[out]scale=out_color_matrix=bt709:out_range=tv,setsar=1[final]'
 run(args+['-filter_complex_threads','1','-filter_complex',flt,'-map','[final]']+common+[str(p)])
 return p
for x in S:
 if len(sys.argv)>1 and x['id'] not in sys.argv[1:]:continue
 files=[render_shot(x,j,s) for j,s in enumerate(x['shots'])]
 lst=W/'render'/f'{x["id"]}.concat';lst.write_text(''.join("file '"+str(p)+"'\n" for p in files))
 raw=W/'render'/f'{x["id"]}-silent.mp4'
 run(['ffmpeg','-y','-v','error','-f','concat','-safe','0','-i',str(lst),'-c','copy',str(raw)])
 music=R/'build/launch/vela-growth-20/public/music'/x['music']
 run(['ffmpeg','-y','-v','error','-i',str(raw),'-ss',str(x['music_offset']),'-i',str(music),'-map','0:v:0','-map','1:a:0','-t',str(x['duration']),'-c:v','copy','-bsf:v','h264_metadata=colour_primaries=1:transfer_characteristics=1:matrix_coefficients=1:video_full_range_flag=0','-af',f'afade=t=in:st=0:d=0.08,afade=t=out:st={x["duration"]-.65}:d=0.65,loudnorm=I=-14:TP=-1.6:LRA=9','-c:a','aac','-b:a','256k','-ar','48000','-ac','2','-metadata','title='+x['title'],'-metadata','comment=Real Vela capture. Film and music provenance in accompanying description.','-movflags','+faststart',str(D/x['file'])])
 print('RENDERED',x['id'],x['duration'],flush=True)
