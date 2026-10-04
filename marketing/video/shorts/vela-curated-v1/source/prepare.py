#!/usr/bin/env python3
"""Editable scene definitions for the six Vela feature Shorts. No app UI is fabricated."""
import json, hashlib, csv
from pathlib import Path
R=Path(__file__).resolve().parents[5]
P=R/'marketing/video/shorts/vela-curated-v1'; D=R/'build/launch/exports/vela-curated-v1'
D.mkdir(parents=True,exist_ok=True)
RAW='build/launch/raw/vela-curated-v1/'
CREDIT='Demo films: Sintel © Blender Foundation / durian.blender.org and Big Buck Bunny © 2008 Blender Foundation / www.bigbuckbunny.org (CC BY 3.0). Library artwork also includes Caminandes: Gran Dillama © Caminandes team / Blender Foundation, (CC) caminandes.com (CC BY-SA 3.0). Film excerpts cropped/resized. Composition: CC BY-SA 3.0, https://creativecommons.org/licenses/by-sa/3.0/. Vela branding and third-party UI/marks retain their own rights. Music: original Ralleur production, existing hauser-D / hauser-F masters; source-film audio removed. Built on Swiftfin: https://github.com/jellyfin/Swiftfin . Vela is independent of Jellyfin, Swiftfin and the filmmakers.'
def shot(src,at,seconds,lines,action,**kw):
 return dict(source=RAW+src+'.mov',source_in=at,source_out=at+seconds,seconds=seconds,lines=lines,action_result=action,crop=[0,32,824,464],**kw)
def close():return dict(seconds=2,lines=['Discover Vela','ralleur.github.io/Vela'],visual='endcard',action_result='Vela wordmark and verified destination; neutral CTA')
def item(n,slug,title,desc,shots):
 if n in (3,4):
  desc+=' Metadata source: TVmaze, https://www.tvmaze.com/shows/45039/slow-horses (CC BY-SA 4.0, https://creativecommons.org/licenses/by-sa/4.0/); dates summarized by Vela.'
 credit=CREDIT if n not in (3,4) else CREDIT.replace('Composition: CC BY-SA 3.0, https://creativecommons.org/licenses/by-sa/3.0/', 'Composition: CC BY-SA 4.0, https://creativecommons.org/licenses/by-sa/4.0/')
 shots=shots+[close()]
 for s in shots:
  if 'source' in s:
   p=R/s['source'];s['source_sha256']=hashlib.sha256(p.read_bytes()).hexdigest()
 return dict(id=f'C{n:02}',product='Vela',version='Mac development capture, 4 Oct 2026; exact capture binary version not retained',revision='v1',language='en',ui_exception='German series-outlook card, explicitly requested by owner',file=f'vela-c{n:02}-{slug}-v1.mp4',duration=sum(s['seconds'] for s in shots),shots=shots,title=title,description=desc+'\n\nVela for macOS · Beta. Local files work without a Jellyfin server. Jellyfin features require your server; episode prompts depend on available chapters/segments and metadata. VLC is the default local playback engine; compatibility depends on the file.\nDiscover Vela: https://ralleur.github.io/Vela/\n\n'+credit+'\n\n#Vela #MacApps #Jellyfin',CTA='Discover Vela',destination='https://ralleur.github.io/Vela/',music='hauser-D.wav' if n%2 else 'hauser-F.wav',music_offset=7 if n%2 else 0)
S=[]
S.append(item(1,'skip-intro','Skip the intro. Get back to the story. | Vela','A real click on Vela’s Skip Intro button jumps to the end of the marked intro. Captured in a local Jellyfin demonstration library with licensed Blender footage and explicit chapter markers. This is metadata-based skipping, not automatic recognition of every intro.',[
 shot('skip-intro-en',12,3.7,['Skip the intro.'],'Visible Skip Intro button; actual click near the end of this shot.',detail=[430,276,370,100],detail_label='SKIP INTRO',note='Jellyfin demo · Requires intro metadata'),
 shot('skip-intro-en',15.7,4.3,['One click.','Back to the story.'],'Button disappears after the real seek to 0:20; playback continues. Final 2 seconds deliberately hold the last captured result.',hold=2,detail=[0,370,330,65],detail_label='STRAIGHT TO THE STORY',note='Jellyfin · Demo library'),
]))
S[-1]['shots'][1]['source_out']=18
S.append(item(2,'next-episode','The next episode is one click away | Vela','Vela shows the next episode’s number and title, then starts it with one click. This recording uses the explicitly named Open Cinema Stories demo library, assembled from licensed Blender clips. The dark first background is the real paused end-of-episode frame; the actual Next Episode control is magnified for readability.',[
 shot('next-episode-en',2,4,['Next episode.','One click.'],'Actual Next Episode prompt with S1:E2 and title; real click and beginning of playback.',detail=[500,306,306, 90],detail_label='NEXT UP',note='Jellyfin demo library'),
 shot('next-episode-en',6,4,['And you’re','already watching.'],'New episode plays continuously after the click; no restart or simulated transition.',note='S1:E2 · Big Buck Bunny · Demo episode')
]))
S.append(item(3,'episode-date','When is the next episode? Vela shows the date.','When your library has no next episode, Vela can display its air date from TVmaze. The real German card reads: “The next episode (S6E4) arrives on Wednesday, 7 October.” This is a clearly labelled metadata demo: live TVmaze information for Slow Horses S6E3 paired with licensed Blender demo footage, not footage from that series. Snapshot captured 4 October 2026, Europe/Berlin. Dates and availability may change. German UI card retained at the owner’s request.',[
 shot('episode-date',0,3,['When’s the','next episode?'],'Actual passive Vela outlook card; held capture, no interaction claimed.',detail=[488,300,308, 80],detail_label='LIVE TVMAZE DATA · DEMO LIBRARY',note='German UI card · Captured 4 Oct 2026'),
 shot('episode-date',3,5,['The date.','Right here.'],'Same continuous capture of the readable air-date card.',detail=[488,300,308,80],detail_label='LIVE TVMAZE DATA · DEMO LIBRARY',note='German UI card · Captured 4 Oct 2026')
]))
S.append(item(4,'season-outlook','Another season? Vela tells you what is known.','Vela’s series outlook distinguishes an announced season from a confirmed premiere date. The real German card says: “Season 7 is announced; there is no date yet.” Live TVmaze metadata for Slow Horses after S6E6, paired with licensed Blender footage in an explicitly named demo library. This is not footage from Slow Horses. Snapshot captured 4 October 2026, Europe/Berlin; metadata may change. German UI card retained at the owner’s request.',[
 shot('season-outlook',0,3,['Another season?'],'Actual passive Vela season-outlook card; no interaction claimed.',detail=[488,300,308,80],detail_label='LIVE TVMAZE DATA · DEMO LIBRARY',note='German UI card · Captured 4 Oct 2026'),
 shot('season-outlook',3,5,['Announced.','Date still pending.'],'Continuous real card accurately distinguishes announced from dated.',detail=[488,300,308,80],detail_label='LIVE TVMAZE DATA · DEMO LIBRARY',note='German UI card · Captured 4 Oct 2026')
]))
S.append(item(5,'less-interface','Less interface. More film. | Vela for Mac','Real Vela Mac playback: controls appear when needed and disappear again, leaving the film. The last three seconds hold the completed clean-window result. “Perfection is achieved, not when there is nothing more to add, but when there is nothing left to take away.” — Antoine de Saint-Exupéry. The on-screen excerpt uses the wording supplied by the owner.',[
 shot('clean-window-en',10,5,['Controls,','when you need them.'],'Actual visible controls fade away during uninterrupted local playback.',note='Local MP4 · Real Vela window'),
 shot('clean-window-en',15,6,['Then just','the film.'],'Actual clean result continues, followed by a deliberate 3-second hold.',hold=3,quote=['“…nothing left','to take away.”','— Antoine de Saint-Exupéry'],note='Local MP4 · Real Vela window')
]))
S[-1]['shots'][1]['source_out']=18
s1=shot('local-result-final',3,2.6,['Open a video.'],'Native file dialog → actual Open action → the same file starts in Vela.',detail=[20,176,305,55],detail_label='YOUR LOCAL FILES',note='Native file dialog · Actual app interaction');s1['crop']=[0,16,880,480]
s2=shot('local-result-final',7.5,4.4,['VLC-powered.','Vela-designed.'],'Same local file plays continuously after opening.',note='Local playback · Compatibility depends on the file');s2['crop']=[28,32,824,464]
bridge=shot('local-result-final',5.6,1,['Open a video.'],'The real file dialog closes and the chosen MP4 appears. A 0.9-second app/decoder flash after this completed opening is omitted.',note='Actual file opening · Brief loading cut')
bridge['crop']=[28,32,824,464]
s3=dict(source='marketing/screenshots/macos/jellyfin-home.jpg',source_in=0,source_out=3,seconds=3,lines=['Jellyfin,','when you want it.'],action_result='Held real Vela Jellyfin home capture; editorial change of source, no connection gesture claimed.',visual='still',crop=None,note='Optional Jellyfin library · Server required',source_sha256=hashlib.sha256((R/'marketing/screenshots/macos/jellyfin-home.jpg').read_bytes()).hexdigest())
S.append(item(6,'your-video-player','Your files. Your Jellyfin library. Your Mac player. | Vela','Open a local MP4 in Vela, watch it with the VLC-based local engine, and connect your Jellyfin library when you want it. The native file dialog and following playback come from one real capture. A 0.9-second app/decoder flash after the opening result is removed; this is not a launch-speed benchmark. The final library view is a clearly separate held capture. Vela supports local MKV, MP4 and MOV workflows; this Short does not claim that every possible file or codec will work, nor does it change Finder defaults.',[s1,bridge,s2,s3]))
(P/'series.json').write_text(json.dumps(S,ensure_ascii=False,indent=2)+'\n')
for x in S:
 (P/(x['id']+'.json')).write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
 (D/x['file'].replace('.mp4','.txt')).write_text(x['title']+'\n\n'+x['description']+'\n')
 rows=[];t=0
 def stamp(v):
  m=int(round(v*1000));return f'{m//3600000:02}:{m//60000%60:02}:{m//1000%60:02},{m%1000:03}'
 for i,s in enumerate(x['shots']):
  rows.append(f'{i+1}\n{stamp(t)} --> {stamp(t+s["seconds"])}\n'+ '\n'.join(s['lines'])+'\n');t+=s['seconds']
 (D/x['file'].replace('.mp4','.srt')).write_text('\n'.join(rows))
with (D/'UPLOAD.csv').open('w') as f:
 w=csv.DictWriter(f,fieldnames=['id','file','title','description','destination','revision']);w.writeheader();w.writerows({k:x[k] for k in w.fieldnames} for x in S)
print('Prepared',len(S),'Shorts in',P)
