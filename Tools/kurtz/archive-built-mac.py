#!/usr/bin/env python3
"""Wrap a verified Release .app in an Xcode distribution archive.
This is a packaging workaround for duplicate host/Catalyst SwiftPM products in
Xcode 27's archive action. The input must first pass a normal Release build.
"""
import argparse,datetime,plistlib,re,subprocess
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('app',type=Path);p.add_argument('archive',type=Path);a=p.parse_args()
app=a.app.resolve();archive=a.archive.resolve()
if archive.exists():raise SystemExit('Refusing to overwrite existing archive')
subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
assert info['CFBundleIdentifier']=='com.ralleur.vela.mac'
sig=subprocess.run(['codesign','-dvv',str(app)],check=True,capture_output=True,text=True).stderr
ent=plistlib.loads(subprocess.check_output(['codesign','-d','--entitlements',':-',str(app)],stderr=subprocess.DEVNULL))
archs=subprocess.check_output(['lipo','-archs',str(app/'Contents/MacOS'/info['CFBundleExecutable'])],text=True).split()
(archive/'Products/Applications').mkdir(parents=True)
subprocess.run(['ditto',str(app),str(archive/'Products/Applications/kurtz.app')],check=True)
props={k:info[k] for k in ('CFBundleIdentifier','CFBundleShortVersionString','CFBundleVersion')}
props.update({'ApplicationPath':'Applications/kurtz.app','Architectures':archs,'SigningIdentity':re.search(r'^Authority=(.+)$',sig,re.M)[1],'Team':ent['com.apple.developer.team-identifier']})
meta={'ArchiveVersion':2,'ApplicationProperties':props,'CreationDate':datetime.datetime.utcnow(),'Name':'kurtz','SchemeName':'Swiftfin'}
(archive/'Info.plist').write_bytes(plistlib.dumps(meta))
print(archive)
