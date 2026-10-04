#!/usr/bin/env python3
"""Render the reviewed edit decisions from genuine app captures; no synthetic UI.
Needs ffmpeg/ffprobe on PATH, Python 3.9+, Pillow, Arial/Arial Bold on macOS.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps
import json, subprocess, hashlib, argparse
R=Path(__file__).resolve().parents[3]
RAW=R/'build/launch/raw'; SHOTS=R/'marketing/screenshots/macos'
OUT=R/'build/launch/exports'; WORK=R/'build/launch/render'; THUMBS=R/'marketing/thumbnails'
for p in (OUT,WORK,THUMBS):p.mkdir(parents=True,exist_ok=True)
FONT='/System/Library/Fonts/Supplemental/Arial.ttf'; BOLD='/System/Library/Fonts/Supplemental/Arial Bold.ttf'
BG='#0d1118'; FG='#f3f5f9'; MUTED='#aeb7c6'; BLUE='#80aaff'
MOVIES={'local-playback.mov':'local-playback-final.mov','jellyfin-playback.mov':'jellyfin-playback-final.mov'}
def run(args): subprocess.run(args,check=True,stdout=subprocess.DEVNULL)
def font(n,bold=False):return ImageFont.truetype(BOLD if bold else FONT,n)
def lines_for(draw,text,f,width):
    lines=[]
    for para in text.split('\n'):
        line=''
        for word in para.split():
            if line and draw.textlength(line+' '+word,font=f)>width:lines.append(line);line=word
            else:line=(line+' '+word).strip()
        lines.append(line)
    return lines

def textblock(draw,text,xy,width,size=64,bold=True,color=FG,max_lines=4):
    while True:
        f=font(size,bold);lines=lines_for(draw,text,f,width)
        if len(lines)<=max_lines:break
        size-=2
    x,y=xy
    for l in lines:
        draw.text((x,y),l,font=f,fill=color);y+=round(size*1.13)
    return y

def crop_still(im,asset,vertical):
    if vertical and asset.startswith('player-'):
        # Matching genuine player crops; no control is moved or invented.
        return im.crop((max(0,im.width-1030),0,im.width,im.height))
    return im

def frame(beat,vertical,last=False,thumbnail=False):
    w,h=(1080,1920) if vertical else (1920,1080)
    im=Image.new('RGB',(w,h),BG);d=ImageDraw.Draw(im)
    x=84 if vertical else 72
    icon=Image.open(R/'marketing/brand/archive-vela/vela-icon.png').convert('RGB').resize((80,80))
    im.paste(icon,(x,160 if vertical else 38))
    d.text((x+96,180 if vertical else 57),'Vela',font=font(34,True),fill=FG)
    if not vertical:d.text((1470,66),'MAC · 0.9.4 SOURCE PREVIEW',font=font(19),fill=MUTED)
    asset=beat.get('asset','');title=beat['text']
    if last and not vertical:
        d.text((x,219),'Built on Swiftfin · Free & open source',font=font(24),fill=MUTED)
    if asset:
        textblock(d,title,(x,310 if vertical else 140),900 if vertical else 1776,76 if vertical else 62,max_lines=3 if vertical else 2)
    else:
        textblock(d,title,(x,620 if vertical else 355),900 if vertical else 1740,90 if vertical else 108,max_lines=5 if vertical else 3)
        d.rectangle((x,555 if vertical else 297,x+76,561 if vertical else 303),fill=BLUE)
    rect=None
    if asset:
        if asset.endswith('.mov'):
            sw,sh=(2400,2160) if vertical else (3840,2160)
        else:
            src=crop_still(Image.open(SHOTS/asset).convert('RGB'),asset,vertical);sw,sh=src.size
        maxw,maxh=(912,780) if vertical else (1776,740)
        scale=min(maxw/sw,maxh/sh)
        nw,nh=int(sw*scale)//2*2,int(sh*scale)//2*2
        px=(w-nw)//2;py=(660+(780-nh)//2) if vertical else (265+(740-nh)//2)
        rect=(px,py,nw,nh)
        if not asset.endswith('.mov'):im.paste(src.resize((nw,nh),Image.Resampling.LANCZOS),(px,py))
        if vertical:
            label='REAL MAC CAPTURE · DETAIL CROP' if asset.startswith('player-') or asset.endswith('.mov') else 'REAL VELA MAC CAPTURE'
            d.text((x,1465),label,font=font(20),fill=MUTED)
    if vertical:
        d.text((x,1530),'github.com/ralleur/Vela',font=font(29,True),fill=BLUE)
        d.text((x,1575),'Free & open source · 0.9.4 beta source preview',font=font(23),fill=MUTED)
        if 'Swiftfin' in title:d.text((x,1620),'github.com/jellyfin/Swiftfin',font=font(25),fill=FG)
        if 'jellyfin-home' in asset or 'jellyfin-detail' in asset:
            credits='Sintel / Big Buck Bunny © Blender Foundation · CC BY 3.0\nCaminandes © Caminandes team / Blender Foundation\n(CC) caminandes.com · CC BY-SA 3.0'
        else:credits='Sintel © Blender Foundation / durian.blender.org\nCC BY 3.0 · Cropped excerpt'
        textblock(d,credits,(x,1680),900,19,False,MUTED,4)
    else:
        d.text((72,1030),'github.com/ralleur/Vela' if last else 'YOUR FILES. YOUR JELLYFIN LIBRARY.',font=font(21,True),fill=BLUE)
        credit='Sintel © Blender Foundation / durian.blender.org · CC BY 3.0'
        if 'jellyfin-' in asset and asset.endswith('.jpg'):credit='Sintel / BBB © Blender Foundation · CC BY 3.0 | Caminandes © Caminandes team / Blender Foundation · CC BY-SA 3.0'
        d.text((1920-72-d.textlength(credit,font=font(16)),1035),credit,font=font(16),fill=MUTED)
    return im,rect

def render(plan,name,vertical):
    folder=WORK/name;folder.mkdir(exist_ok=True)
    pieces=[];proof=[]
    for i,beat in enumerate(plan['beats']):
        base,rect=frame(beat,vertical,i==len(plan['beats'])-1)
        bg=folder/f'{i:02d}.png';base.save(bg);proof.append(base)
        dest=folder/f'{i:02d}.mp4';args=['ffmpeg','-hide_banner','-loglevel','error','-y','-loop','1','-framerate','30','-i',str(bg)]
        asset=beat.get('asset','')
        if asset.endswith('.mov'):
            movie=RAW/MOVIES.get(asset,asset)
            args+=['-i',str(movie)]
            px,py,nw,nh=rect
            # Captures include a 32 px external title strip, excluded here.
            crop='crop=2400:2160:1200:32' if vertical else 'crop=3840:2160:0:32'
            filt=f'[1:v]{crop},fps=30,scale={nw}:{nh}:flags=lanczos,setsar=1[v];[0:v][v]overlay={px}:{py}:shortest=1,format=yuv420p[out]'
            args+=['-filter_complex',filt,'-map','[out]']
        args+=['-t',str(beat['duration']),'-an','-r','30','-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p','-threads','4','-movflags','+faststart',str(dest)]
        run(args);pieces.append(dest)
    listing=folder/'concat.txt';listing.write_text(''.join("file '"+p.name+"'\n" for p in pieces))
    final=OUT/f'{name}.mp4'
    run(['ffmpeg','-hide_banner','-loglevel','error','-y','-f','concat','-safe','0','-i',str(listing),'-c','copy','-metadata','title='+plan.get('title',plan.get('youtube_title',name)),'-metadata','comment=Real Vela 0.9.4 Mac captures. Composition CC BY-SA 3.0. Film credits and sources in marketing/sources-and-licenses.md.','-movflags','+faststart',str(final)])
    (OUT/f'{name}.description.txt').write_text(plan['description']+'\n')
    # Representative decoded frames, including moving shots, for visual review.
    contact=Image.new('RGB',(960, (len(pieces)+2)//3*(568 if vertical else 196)),BG)
    time=0
    for i,beat in enumerate(plan['beats']):
        still=folder/f'check-{i:02d}.jpg'
        run(['ffmpeg','-hide_banner','-loglevel','error','-y','-ss',str(time+min(2,beat['duration']/2)),'-i',str(final),'-frames:v','1',str(still)])
        thumb=Image.open(still);thumb.thumbnail((320,568 if vertical else 180));contact.paste(thumb,((i%3)*320,(i//3)*(568 if vertical else 196)))
        time+=beat['duration']
    contact.save(folder/'contact-sheet.jpg',quality=92)
    info=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration,size:stream=codec_name,width,height,r_frame_rate,pix_fmt','-of','json',str(final)]))
    assert abs(float(info['format']['duration'])-plan['duration'])<.2,(name,info)
    run(['ffmpeg','-hide_banner','-loglevel','error','-i',str(final),'-f','null','-'])
    info.update({'file':str(final.relative_to(R)),'sha256':hashlib.sha256(final.read_bytes()).hexdigest(),'silent':True,'review_contact_sheet':str((folder/'contact-sheet.jpg').relative_to(R))})
    print(name,info['format'],flush=True)
    return info

def thumbnail(text,name,vertical=True):
    w,h=(1080,1920) if vertical else (1280,720)
    im=Image.new('RGB',(w,h),BG);d=ImageDraw.Draw(im)
    mark=Image.open(R/'marketing/brand/archive-vela/vela-icon.png').resize((110,110));im.paste(mark,(70,180 if vertical else 40))
    d.text((198,215 if vertical else 70),'Vela',font=font(42,True),fill=FG)
    textblock(d,text,(78,400 if vertical else 235),920 if vertical else 580,112 if vertical else 90,max_lines=3)
    hero=Image.open(SHOTS/'player-clean.jpg')
    if vertical:im.paste(ImageOps.fit(hero,(1080,660),centering=(.7,.5)),(0,900))
    else:im.paste(ImageOps.fit(hero,(570,510),centering=(.7,.5)),(710,110))
    d.text((78,1630 if vertical else 640),'YOUR FILES. YOUR JELLYFIN LIBRARY.',font=font(26 if vertical else 19,True),fill=BLUE)
    d.text((78,1710 if vertical else 682),'Sintel © Blender Foundation / durian.blender.org · CC BY 3.0',font=font(19 if vertical else 13),fill=MUTED)
    im.save(THUMBS/f'{name}.jpg',quality=94,optimize=True)

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--only');ap.add_argument('--thumbnails-only',action='store_true');args=ap.parse_args()
    main=json.loads((R/'marketing/video/product/timeline.json').read_text())
    shorts=json.loads((R/'marketing/video/shorts/launch-batch.json').read_text())
    thumbnail('ONE\nPLAYER.','product-video',False)
    for s in shorts:thumbnail(s['thumbnail'],f"{s['id']}-{s['slug']}")
    result=[]
    if not args.thumbnails_only:
        if not args.only or args.only=='product':result.append(render(main,'vela-product-60s',False))
        for s in shorts:
            if s['priority']=='render' and (not args.only or args.only==s['id']):result.append(render(s,f"vela-short-{s['id']}-{s['slug']}",True))
        (OUT/('render-manifest'+('-'+args.only if args.only else '')+'.json')).write_text(json.dumps(result,indent=2)+'\n')
