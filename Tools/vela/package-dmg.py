#!/usr/bin/env python3
"""Package an already-built Vela Mac app without changing its signature.

Production usage requires a Developer ID signature and a stapled notarization
 ticket. A development-only image can be produced explicitly for local review;
 it is named DEVELOPMENT-ONLY and must not become the website download.
"""
from pathlib import Path
import argparse,hashlib,json,plistlib,shutil,subprocess

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('app',type=Path)
p.add_argument('--output',type=Path,default=Path('build/release'))
p.add_argument('--development-preview',action='store_true')
a=p.parse_args();app=a.app.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
info=plistlib.loads((app/'Contents/Info.plist').read_bytes());version=info['CFBundleShortVersionString']
assert info['CFBundleIdentifier']=='com.ralleur.vela.mac','Unexpected app identity'
subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
signature=subprocess.run(['codesign','-dvv',str(app)],capture_output=True,text=True,check=True).stderr
binary=app/'Contents/MacOS'/info['CFBundleExecutable']
archs=subprocess.check_output(['lipo','-archs',str(binary)],text=True).split()
assert {'arm64','x86_64'}.issubset(archs),'Release must include both Mac architectures'
if not a.development_preview:
    assert 'Authority=Developer ID Application:' in signature,'A public DMG requires Developer ID Application signing'
    subprocess.run(['xcrun','stapler','validate',str(app)],check=True)
    subprocess.run(['spctl','--assess','--type','execute','--verbose=2',str(app)],check=True)
suffix='-DEVELOPMENT-ONLY' if a.development_preview else ''
name=f'Vela-{version}-macOS-universal{suffix}'
stage=out/(name+'-contents')
if stage.exists():raise SystemExit(f'Refusing to overwrite staging directory: {stage}')
stage.mkdir();subprocess.run(['ditto',str(app),str(stage/'Vela.app')],check=True)
(stage/'Applications').symlink_to('/Applications',target_is_directory=True)
root=Path(__file__).resolve().parents[2]
shutil.copy2(root/'Shared/Resources/VelaThirdPartyNotices.txt',stage/'Open Source Notices.txt')
shutil.copy2(root/'LICENSE.md',stage/'Vela Source License.txt')
if not a.development_preview:
    shutil.copytree(root/'docs/release',stage/'Licenses and Source')
message=f'''Vela {version} Beta for macOS\n\nDrag Vela.app to Applications. macOS {info.get('LSMinimumSystemVersion','15.6')} or later.\nApple silicon and Intel.\n\nSource and release information:\nhttps://github.com/ralleur/Vela/releases/tag/vela-{version}\nhttps://github.com/ralleur/Vela\nhttps://github.com/ralleur/Vela/blob/vela-{version}/docs/release/README.md\n\nBased on Swiftfin. Free and open source.\n'''
if a.development_preview:message+='\nDEVELOPMENT-ONLY: this image is not a public installer. Its provisioning\nprofile restricts it to registered test Macs. It is not notarized.\n'
(stage/'Read Me.txt').write_text(message)
dmg=out/(name+'.dmg')
if dmg.exists():raise SystemExit(f'Refusing to overwrite: {dmg}')
# macOS 27 uses DiskImages2; its folder image path avoids the legacy
# hdiutil HFS+ staging collision. Keep a fallback for older build hosts.
modern=subprocess.run(['diskutil','image','create','from','--help'],capture_output=True).returncode==0
command=(['diskutil','image','create','from','--format','UDZO','--volumeName',f'Vela {version}',str(stage),str(dmg)] if modern else ['hdiutil','create','-fs','HFS+','-volname',f'Vela {version}','-srcfolder',str(stage),'-format','UDZO',str(dmg)])
subprocess.run(command,check=True)
subprocess.run(['hdiutil','verify',str(dmg)],check=True)
sha=hashlib.sha256(dmg.read_bytes()).hexdigest()
(dmg.with_suffix('.dmg.sha256')).write_text(f'{sha}  {dmg.name}\n')
manifest={'file':dmg.name,'sha256':sha,'version':version,'build':info['CFBundleVersion'],'architectures':archs,'minimum_macos':info.get('LSMinimumSystemVersion'),'development_only':a.development_preview,'size':dmg.stat().st_size}
(dmg.with_suffix('.json')).write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest,indent=2))
