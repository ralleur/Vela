#!/usr/bin/env python3
import json,html,subprocess,shutil
from pathlib import Path
R=Path(__file__).resolve().parents[5];P=R/'marketing/video/shorts/vela-curated-v1';D=R/'build/launch/exports/vela-curated-v1';W=R/'build/launch/vela-curated-v1'
S=json.loads((P/'series.json').read_text());e=html.escape
(D/'previews').mkdir(exist_ok=True)
for x in S:
 subprocess.run(['ffmpeg','-y','-v','error','-i',str(D/x['file']),'-frames:v','1','-vf','scale=360:640',str(D/'previews'/f'{x["id"]}.jpg')],check=True)
 shutil.copy(P/(x['id']+'.json'),D/(x['id']+'.json'))
shutil.copy(P/'series.json',D/'series.json')
cards=[]
for x in S:
 cards.append(f'''<article id="{x['id']}"><div class="kicker">{x['id']} · {x['duration']:g} SECONDS · V1</div><h2>{e(x['title'])}</h2><video preload="metadata" playsinline controls poster="previews/{x['id']}.jpg" src="{x['file']}"></video><p class="links"><a href="{x['file']}" download>Download MP4</a><a href="{x['file'].replace('.mp4','.srt')}">Captions</a><a href="{x['file'].replace('.mp4','.txt')}">Title &amp; description</a></p><details><summary>Exact description</summary><pre>{e(x['description'])}</pre></details></article>''')
page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Vela — Curated Shorts v1</title><style>
*{box-sizing:border-box}body{margin:0;background:#0d1118;color:#f3f5f9;font:16px/1.5 -apple-system,BlinkMacSystemFont,Arial,sans-serif}main{max-width:1240px;margin:auto;padding:48px 30px}header{max-width:820px;margin-bottom:40px}.kicker{color:#80aaff;font-size:12px;font-weight:700;letter-spacing:1.5px}h1{font-size:52px;line-height:1.06;letter-spacing:-2px;margin:18px 0}header p{color:#aeb7c6}a{color:#80aaff}button{background:#80aaff;color:#0d1118;padding:12px 19px;border:0;border-radius:8px;cursor:pointer;font-weight:700}section{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:32px}article{min-width:0;background:#151c27;border:1px solid #303947;border-radius:16px;padding:18px}h2{font-size:19px;min-height:58px;line-height:1.35}video{display:block;width:100%;aspect-ratio:9/16;border-radius:8px;background:#080b10}.links{display:flex;flex-wrap:wrap;gap:12px;font-size:13px}summary{cursor:pointer;color:#aeb7c6}pre{white-space:pre-wrap;word-break:break-word;font:13px/1.6 Arial,sans-serif}footer{color:#aeb7c6;margin-top:40px}.status{font-size:14px;color:#aeb7c6;margin-top:12px}#review-state{color:#80aaff}@media(max-width:600px){main{padding:26px 16px}h1{font-size:38px}}
</style><main><header><div class="kicker">VELA / SIX FEATURE SHORTS / V1</div><h1>Less interface.<br>More film.</h1><p>Real Vela recordings, Vela branding, English copy. German series-outlook cards are preserved as requested. The outlook examples use live TVmaze metadata in a labelled demonstration library.</p><p>1080 × 1920 · 30 fps · 10–13 seconds · Original music · Local delivery</p><button id="review">Play all at 1×</button> <a href="UPLOAD.csv">Titles &amp; descriptions</a> · <a href="VALIDATION.txt">Validation record</a><div class="status" id="review-state">Ready. Nothing has been uploaded or scheduled.</div></header><section>'''+''.join(cards)+'''</section><footer>Film and music credits are included in every description. Final videos are unchanged when this preview is played. Captured dates are examples, not a promise about current availability.</footer></main><script>
const videos=[...document.querySelectorAll('video')];let reviewing=false,index=0;
for(const video of videos)video.addEventListener('play',()=>{videos.forEach(v=>{if(v!==video)v.pause()})});
function next(){if(index>=videos.length){document.querySelector('#review-state').textContent='All six previews completed at 1×.';reviewing=false;return}const v=videos[index];v.currentTime=0;v.playbackRate=1;v.closest('article').scrollIntoView({behavior:'smooth',block:'start'});document.querySelector('#review-state').textContent='Playing '+v.closest('article').id+' at 1×';v.play()}
document.querySelector('#review').onclick=()=>{reviewing=true;index=0;next()};videos.forEach(v=>v.addEventListener('ended',()=>{if(reviewing&&v===videos[index]){index++;next()}}));
</script></html>'''
(D/'INDEX.html').write_text(page)
print(D/'INDEX.html')
