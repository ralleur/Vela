#!/usr/bin/env python3
"""Download immutable upstream source archives and index binary build recipes.
No upstream code is executed. Needs gh/curl, authenticated GitHub read access.
Large source archives stay under ignored build/release/source-inputs.
"""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import hashlib,json,subprocess,urllib.parse
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'build/release/source-inputs';OUT.mkdir(parents=True,exist_ok=True)
PINS=json.loads((ROOT/'Swiftfin.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved').read_text())['pins']
items=[]
for p in PINS:
 url=p['location'].rstrip('/').removesuffix('.git');repo=url.split('github.com/')[-1]
 if 'github.com/' not in url:raise SystemExit('Non-GitHub source needs explicit support: '+url)
 items.append({'id':p['identity'],'kind':'Swift package','repo':repo,'ref':p['state']['revision']})
items += [
 {'id':'mpv','kind':'engine source','repo':'mpv-player/mpv','ref':'41f6a645068483470267271e1d09966ca3b9f413'},
 {'id':'ffmpeg','kind':'engine source','repo':'FFmpeg/FFmpeg','ref':'38b88335f99e76ed89ff3c93f877fdefce736c13'},
 {'id':'vlc','kind':'engine source','repo':'videolan/vlc','ref':'c833c4be0'},
 {'id':'mpvkit-recipe','kind':'build recipe','repo':'mpvkit/MPVKit','ref':'288527dffbc6d3e63cce147fc7b520c64a791603'},
]
lock=json.loads((ROOT/'docs/release/MPVUI-Inputs.lock.json').read_text());recipes={}
for dep in lock['dependencies']:
 parts=dep['url'].split('/');recipes['/'.join(parts[3:5])]=parts[7]
for repo,ref in recipes.items():items.append({'id':repo.split('/')[-1],'kind':'component build recipe','repo':repo,'ref':ref})
def collect(item):
 endpoint=f"repos/{item['repo']}/commits/{urllib.parse.quote(item['ref'],safe='')}"
 commit=json.loads(subprocess.check_output(['gh','api',endpoint]))['sha']
 url=f"https://codeload.github.com/{item['repo']}/tar.gz/{commit}"
 path=OUT/f"{item['id']}-{commit[:12]}.tar.gz"
 if not path.exists():subprocess.run(['curl','-fLsS','--retry','3','--max-time','180','-o',str(path),url],check=True)
 item.update({'commit':commit,'source_url':f"https://github.com/{item['repo']}/tree/{commit}",'archive_url':url,'archive':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size':path.stat().st_size})
 print(item['id'],path.stat().st_size,flush=True);return item
with ThreadPoolExecutor(max_workers=4) as pool:result=list(pool.map(collect,items))
(ROOT/'docs/release/source-index.json').write_text(json.dumps(result,indent=2)+'\n')
print('Collected',len(result),'source/recipe archives')
