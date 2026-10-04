#!/usr/bin/env python3
import json,subprocess,concurrent.futures,sys
from pathlib import Path
R=Path(__file__).resolve().parents[5];P=R/'marketing/video/shorts/kurtz-curated-v2';W=R/'build/launch/kurtz-curated-v2';D=R/'build/launch/exports/kurtz-curated-v2'
S=json.loads((P/'series.json').read_text())
def check(x):
 out=W/'qa'/x['id'];out.mkdir(parents=True,exist_ok=True)
 r=subprocess.run(['python3','/Users/ai/.codex/skills/ralleur-shorts/scripts/audit_short.py',str(D/x['file']),'--item',str(P/(x['id']+'.json')),'--out',str(out)],capture_output=True,text=True)
 print(x['id'],r.stdout.strip(),r.stderr[-500:],flush=True)
 # Full timeline samples at 4 fps for editorial review, in 3-second pages.
 for start in range(0,int(x['duration']),3):
  subprocess.run(['ffmpeg','-y','-v','error','-ss',str(start),'-i',str(D/x['file']),'-t',str(min(3,x['duration']-start)),'-vf','fps=4,scale=216:384,tile=4x3','-frames:v','1',str(out/f'temporal-{start:02}.jpg')],check=True)
 subprocess.run(['ffmpeg','-hide_banner','-nostats','-i',str(D/x['file']),'-vf','blackdetect=d=0.05:pic_th=0.98,freezedetect=n=-55dB:d=1','-an','-f','null','-'],stderr=(out/'black-freeze.log').open('w'),stdout=subprocess.DEVNULL,check=True)
 return json.loads((out/'report.json').read_text())
selected=[x for x in S if len(sys.argv)==1 or x['id'] in sys.argv[1:]]
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool: list(pool.map(check,selected))
reports=[json.loads((W/'qa'/x['id']/'report.json').read_text()) for x in S]
(P/'technical-validation.json').write_text(json.dumps(reports,indent=2)+'\n')
