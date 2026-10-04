"""Check the actual delivery files and extract every edited scene for visual QA."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from PIL import Image,ImageDraw
import json,subprocess,re,hashlib,sys
R=Path(__file__).resolve().parents[3];P=R/'marketing/video/shorts/vela-growth-20';W=R/'build/launch/vela-growth-20/out';D=R/'build/launch/exports/vela-shorts-en';PV=D/'previews';PV.mkdir(exist_ok=True)
series=json.loads((P/'series.json').read_text())
def run(s):
 file=D/s['file'];info=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(file)]))
 v=next(x for x in info['streams'] if x['codec_type']=='video');a=next(x for x in info['streams'] if x['codec_type']=='audio')
 assert (v['width'],v['height'],v['r_frame_rate'],v['pix_fmt'],v['codec_name'],v['color_space'])==(1080,1920,'30/1','yuv420p','h264','bt709'),s['id']
 assert a['codec_name']=='aac' and a['channels']==2 and a['sample_rate']=='48000',s['id']
 assert int(v['nb_frames'])==round(s['duration']*30) and abs(float(info['format']['duration'])-s['duration'])<.08,s['id']
 decoded=subprocess.run(['ffmpeg','-hide_banner','-nostats','-i',str(file),'-af','ebur128=peak=true','-f','null','-'],capture_output=True,text=True);(W/f"{s['id']}-decode.log").write_text(decoded.stderr)
 assert decoded.returncode==0,s['id']
 summary=decoded.stderr.rsplit('Summary:',1)[-1];loud=float(re.search(r'I:\s+(-?[\d.]+) LUFS',summary).group(1));peak=float(re.search(r'Peak:\s+(-?[\d.]+) dBFS',summary).group(1))
 assert -15<=loud<=-13 and peak<=-.5,(s['id'],loud,peak)
 samples=[]
 for i,b in enumerate(s['beats']):
  sample=W/f"final-{s['id']}-{i}.jpg";t=b['start']+min(1.5,b['duration']/2)
  subprocess.run(['ffmpeg','-y','-v','error','-ss',str(t),'-i',str(file),'-frames:v','1','-vf','scale=270:480',str(sample)],check=True);samples.append(str(sample.relative_to(R)))
 subprocess.run(['ffmpeg','-y','-v','error','-ss','1.35','-i',str(file),'-frames:v','1','-vf','scale=540:960',str(PV/f"{s['id']}.jpg")],check=True)
 print(s['id']+f' PASS · {s["duration"]}s · {loud} LUFS · {peak} dBTP',flush=True)
 return dict(id=s['id'],file=str(file.relative_to(R)),width=1080,height=1920,fps=30,frames=int(v['nb_frames']),duration=s['duration'],video='H.264 yuv420p BT.709 limited',audio='AAC stereo 48kHz',integratedLUFS=loud,truePeakDBFS=peak,fullDecode='passed',sha256=hashlib.sha256(file.read_bytes()).hexdigest(),samples=samples)
selected=[s for s in series if not sys.argv[1:] or s['id'] in sys.argv[1:]]
with ThreadPoolExecutor(max_workers=3) as pool:fresh=list(pool.map(run,selected))
old=json.loads((P/'render-manifest.json').read_text())['files'] if sys.argv[1:] else []
byid={s['id']:s for s in old+fresh};result=[byid[s['id']] for s in series]
assert len(result)==20 and len({s['sha256'] for s in result})==20
(P/'render-manifest.json').write_text(json.dumps(dict(status='passed',count=20,files=result),indent=2)+'\n')
for group in range(5):
 out=Image.new('RGB',(1620,2060),'#0d1118');draw=ImageDraw.Draw(out)
 for row,item in enumerate(result[group*4:group*4+4]):
  draw.text((8,row*515+6),item['id']+' / scene order',fill='white')
  for col,p in enumerate(item['samples']):out.paste(Image.open(R/p),(col*270,row*515+30))
 out.save(PV/f'scenes-{group+1}.jpg',quality=92)
out=Image.new('RGB',(1350,2020),'#0d1118');draw=ImageDraw.Draw(out)
for i,s in enumerate(series):
 im=Image.open(PV/f"{s['id']}.jpg");im.thumbnail((270,480));x=i%5*270;y=i//5*505;out.paste(im,(x,y+25));draw.text((x+8,y+5),s['id'],fill='white')
out.save(D/'HOOKS-20.jpg',quality=92)
print('20 final exports passed; all-scene contact sheets saved.')
