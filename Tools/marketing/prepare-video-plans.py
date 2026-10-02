#!/usr/bin/env python3
"""Write the editable launch timeline, individual Shorts plans and timed captions."""
from pathlib import Path
import json
R=Path(__file__).resolve().parents[2];V=R/'marketing/video';V.mkdir(exist_ok=True)
CREDIT='Demo: Sintel © Blender Foundation / durian.blender.org (CC BY 3.0); Big Buck Bunny © 2008 Blender Foundation / www.bigbuckbunny.org (CC BY 3.0); Caminandes: Gran Dillama © Caminandes team / Blender Foundation, (CC) caminandes.com (CC BY-SA 3.0). Cropped/resized excerpts and demo artwork. Video composition: CC BY-SA 3.0, https://creativecommons.org/licenses/by-sa/3.0/. Vela is based on Swiftfin; independent, not endorsed by Jellyfin or Swiftfin.'
STATUS='Vela 0.9.4 beta source preview. The older 0.9.3 download predates local playback and is development-signed, not notarized. Build: https://github.com/ralleur/Vela'
def shot(duration,text,asset='',crop='contain',action='Hold; no simulated UI interaction',status='captured'):
 return dict(duration=duration,text=text,asset=asset,crop=crop,action=action,transition='clean cut',capture_status=status if asset else 'typeset',voiceover='None in silent master; optional VO is the on-screen text.')
product=[
 shot(5,'A file. A library.\nWhy choose a different app?'),
 shot(5,'Open the file.','local-workflow.jpg',action='Actual native Open Video picker; selected MKV'),
 shot(7,'Vela plays it.','local-playback.mov',action='Actual local playback; live screen recording'),
 shot(5,'Your Jellyfin library lives here, too.','jellyfin-home.jpg',crop='library',action='Actual demo home; inspect the real movie row'),
 shot(5,'Choose a film.','jellyfin-detail.jpg',action='Actual Jellyfin detail page; Play is visible'),
 shot(5,'The same player.','jellyfin-playback.mov',action='Actual server playback; live screen recording'),
 shot(5,'Your language. Your pace.','subtitles.jpg',crop='contain',action='Actual embedded-subtitle menu; no invented track list'),
 shot(6,'Then the controls get out of the way.','player-clean.jpg',action='Real captured clean state; optional watermark off'),
 shot(6,'Built on Swiftfin.\nWith gratitude.', 'jellyfin-detail.jpg',action='Credit Swiftfin and its Apple Jellyfin client foundation'),
 shot(5,'No subscription. No Pro tier.\nThe whole app is free.'),
 shot(6,'Vela. Just watch the video.', 'player-clean.jpg',action='End card includes repository, source-beta status and film credits'),
]
shorts=[
 dict(id='01',slug='why-choose',working_title='The unnecessary choice',hook='Why choose an app before choosing a video?',youtube_title='Why do local videos and Jellyfin need different apps?',thumbnail='WHY TWO APPS?',duration=18,
 beats=[shot(5,'A file in Downloads.','local-workflow.jpg'),shot(5,'A film on Jellyfin.','jellyfin-home.jpg','library'),shot(8,'One activity.\nOne player.','player-clean.jpg')]),
 dict(id='02',slug='play-the-file',working_title='A good idea, carried forward',hook='A player should just play the file.',youtube_title='VLC got this right. Vela starts from the same expectation.',thumbnail='PLAY THE FILE',duration=20,
 beats=[shot(5,'A player should\njust play the file.'),shot(5,'Thank you, VideoLAN.\nVela uses libVLC.'),shot(5,'Now put your Jellyfin\nlibrary beside it.','jellyfin-detail.jpg'),shot(5,'Your files. Your library.','player-clean.jpg')]),
 dict(id='03',slug='disappearing-ui',working_title='Room for the film',hook='The player is still here.',youtube_title='The best part of Vela’s player UI? Watching it disappear.',thumbnail='JUST THE VIDEO',duration=18,
 beats=[shot(5,'There when you need it.','player-controls.jpg'),shot(8,'Gone when you don’t.','player-clean.jpg'),shot(5,'Vela. Just watch the video.','player-clean.jpg')]),
 dict(id='04',slug='local-and-jellyfin',working_title='Two sources, one player',hook='Your MKV. Your Jellyfin library.',youtube_title='Your MKV and your Jellyfin library. One Mac player.',thumbnail='ONE PLAYER',duration=20,
 beats=[shot(5,'Your MKV.','local-workflow.jpg'),shot(5,'Your Jellyfin library.','jellyfin-detail.jpg'),shot(5,'The same player.','jellyfin-playback.mov',action='Actual server playback; live screen recording'),shot(5,'Vela. Local or Jellyfin.','player-clean.jpg')]),
 dict(id='05',slug='whole-app-free',working_title='This is the version',hook='Remember when great apps were just free?',youtube_title='No Pro version. Vela is the whole app.',thumbnail='NO PRO VERSION',duration=18,
 beats=[shot(5,'Remember when great apps\nwere just free?'),shot(4,'No subscription.'),shot(4,'No in-app purchases.\nNo Pro unlock.'),shot(5,'Vela is free\nand open source.','player-clean.jpg')]),
 dict(id='06',slug='built-on-swiftfin',working_title='Start with something good',hook='I didn’t build the Jellyfin part from scratch.',youtube_title='Vela started with Swiftfin. That belongs in the story.',thumbnail='THANK YOU, SWIFTFIN',duration=22,
 beats=[shot(5,'I didn’t build the Jellyfin\npart from scratch.'),shot(6,'Swiftfin built the\nApple client foundation.','jellyfin-detail.jpg'),shot(6,'Vela asks:\nwhy stop at the server?','local-workflow.jpg'),shot(5,'Built on Swiftfin.\nWith gratitude.')]),
 dict(id='07',slug='default-player',working_title='Choose your default',hook='A double-click can be enough.',youtube_title='Make Vela your Mac’s default player for MKVs',thumbnail='DOUBLE-CLICK. PLAY.',duration=20,
 beats=[shot(5,'A double-click\ncan be enough.'),shot(7,'Finder → Get Info\nOpen with → Vela', 'finder-get-info.mov',action='Select a demo MKV; open Get Info; choose Vela; show Change All without changing the user’s defaults',status='not captured; exact pickup specified'),shot(4,'Choose the default\nfor that file type.'),shot(4,'Then just open the video.','player-clean.jpg')]),
 dict(id='08',slug='small-comforts',working_title='Nothing extraordinary',hook='Nothing revolutionary. That’s the point.',youtube_title='Subtitles. Resume. Fullscreen. Nothing revolutionary.',thumbnail='JUST PRESS PLAY',duration=24,
 beats=[shot(4,'Open a video.','local-workflow.jpg'),shot(5,'Choose your subtitles.','subtitles.jpg'),shot(5,'Keep your place.','jellyfin-home.jpg','library',action='Real Jellyfin Continue; explain local history separately in description'),shot(5,'Make room for the film.','fullscreen.jpg'),shot(5,'Nothing revolutionary.\nThat’s the point.','player-clean.jpg')]),
]
def stamp(t,sep=','):
 ms=round(t*1000);return f'{ms//3600000:02}:{ms//60000%60:02}:{ms//1000%60:02}{sep}{ms%1000:03}'
def captions(beats,path):
 t=0;srt=[];vtt=['WEBVTT\n']
 for i,b in enumerate(beats,1):
  srt.append(f'{i}\n{stamp(t)} --> {stamp(t+b["duration"])}\n{b["text"]}\n');vtt.append(f'{stamp(t,".")} --> {stamp(t+b["duration"],".")}\n{b["text"]}\n');t+=b['duration']
 path.with_suffix('.srt').write_text('\n'.join(srt));path.with_suffix('.vtt').write_text('\n'.join(vtt))
 return t
product_plan={'title':'Vela — Just watch the video.','format':'1920×1080, 30 fps, silent, text-led','duration':60,'beats':product,'description':STATUS+'\n\n'+CREDIT}
(V/'product/timeline.json').write_text(json.dumps(product_plan,indent=2,ensure_ascii=False)+'\n');captions(product,V/'product/captions')
for s in shorts:
 s['description']=s['hook']+'\n\n'+STATUS+'\n\n'+CREDIT
 s['hashtags']=['#Vela','#OpenSource'] if s['id'] in ['05','06'] else ['#Vela','#Jellyfin']
 s['framing']='1080×1920; headlines in top safe area, native UI crops at readable scale, credits below. Main text and CTA use x=84…996 and y=310…1610; supplemental film credits sit below and repeat in the description. No central 9:16 crop of a whole desktop.'
 s['thumbnail_concept']='Vela glyph, '+s['thumbnail']+', one genuine capture crop on navy. No face, badges or competing claims.'
 s['priority']='render' if s['id'] in ['03','04','05','06'] else 'fully specified; pickup if marked'
 captions(s['beats'],V/'shorts'/s['slug'])
(V/'shorts/launch-batch.json').write_text(json.dumps(shorts,indent=2,ensure_ascii=False)+'\n')
# Human-readable exact shot lists generated from the editable plans.
def table(beats):
 rows=['| Shot | Time | Application state / required asset | User action | Camera / crop | On-screen text | Transition | Capture status |','| --- | --- | --- | --- | --- | --- | --- | --- |'];t=0
 for i,b in enumerate(beats,1):
  rows.append(f'| {i:02} | {t}–{t+b["duration"]}s | {b["asset"] or "Vela title card"} | {b["action"]} | {b["crop"]} | '+b['text'].replace('\n',' / ')+f' | {b["transition"]} | {b["capture_status"]} |');t+=b['duration']
 return '\n'.join(rows)
(V/'product/production.md').write_text('# Vela product film\n\n60 seconds. A silent, text-led launch film made from real screenshots and screen recordings. Optional voiceover follows the on-screen text; no voice or music is required for this cut.\n\n'+table(product)+'\n\n## Edit\n\nCuts only. Static screenshots are deliberate held shots, not simulated screen recordings. Preserve native UI proportions. Crop the outer macOS title strip only where documented. All title copy sits outside the app picture. The final card carries source-beta status, GitHub URL, Swiftfin credit and film credits. SRT/VTT files repeat the visible narrative for publishing.\n\n## YouTube\n\nTitle: Vela — Your files. Your Jellyfin library. One Mac player.\n\n'+STATUS+'\n\n'+CREDIT+'\n')
text='# Eight Vela launch Shorts\n\nAll scripts are 18–24 seconds. The selected silent masters are 03, 04, 05 and 06. Voiceover is optional and uses the on-screen lines verbatim. Individual SRT/VTT files are supplied.\n'
for s in shorts:
 text+=f'\n## {s["id"]} — {s["working_title"]}\n\n**Hook:** {s["hook"]}\n\n**YouTube title:** {s["youtube_title"]}\n\n**Duration:** {s["duration"]} seconds.\n\n**Thumbnail:** {s["thumbnail_concept"]}\n\n**Framing:** {s["framing"]}\n\n'+table(s['beats'])+'\n\n**Description:**\n\n'+s['description']+'\n\n'+' '.join(s['hashtags'])+'\n'
text+='\n## Additional distinct follow-ups\n\n- **One retry, another engine**: show a known failing local fixture and the real Try Compatible Playback action. Explain VLC/mpv without promising universal decoding. Capture the error and successful retry before publishing.\n- **No account for a file**: cold account-free startup, native Open Video, playback. Demonstrate the absence of a signup flow without claiming zero network traffic.\n- **A place beside your work**: enter and exit the floating mini player. Call it a mini player; do not label it system Picture-in-Picture.\n'
(V/'shorts/production.md').write_text(text)
print('Wrote main film and 8 complete Shorts plans with SRT/VTT captions')
