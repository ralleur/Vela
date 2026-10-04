from pathlib import Path
import subprocess
from concurrent.futures import ThreadPoolExecutor
R=Path(__file__).resolve().parent
RAW=R.parent/'raw'
def run(name):
 subprocess.run(['ffmpeg','-y','-v','error','-i',str(RAW/f'{name}-playback-final.mov'),'-an','-vf','crop=3840:2160:0:32,scale=1600:900,fps=30','-c:v','libx264','-crf','17','-preset','fast','-threads','2','-pix_fmt','yuv420p',str(R/'public/media'/f'{name}.mp4')],check=True)
 print(name,flush=True)
with ThreadPoolExecutor(max_workers=2) as p:list(p.map(run,['local','jellyfin']))
