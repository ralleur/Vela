#!/usr/bin/env python3
"""Verify a built Mac bundle without installing or publishing it.

Usage: Tools/kurtz/verify-mac-build.py [path/to/kurtz.app] [--universal]
This checks packaging, not Gatekeeper/notarization or binary license compliance.
"""
import argparse
from pathlib import Path
import plistlib
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('app', nargs='?', default='build/dd-mac/Build/Products/Release-maccatalyst/kurtz.app')
parser.add_argument('--universal', action='store_true')
args = parser.parse_args()
app = Path(args.app).resolve()
with (app / 'Contents/Info.plist').open('rb') as stream:
    info = plistlib.load(stream)

def require(condition, message):
    if not condition:
        raise SystemExit('FAIL: ' + message)
    print('PASS: ' + message)

require(info.get('CFBundleDisplayName') == 'kurtz', 'kurtz display name')
require(info.get('CFBundleIdentifier') == 'com.ralleur.vela.mac', 'Mac bundle identifier')
require(info.get('CFBundleShortVersionString', '').startswith('0.9.'), 'Beta version')
require(info.get('LSApplicationCategoryType') == 'public.app-category.entertainment', 'App category')
types = {t for doc in info.get('CFBundleDocumentTypes', []) for t in doc.get('LSItemContentTypes', [])}
require('public.movie' in types, 'Video document registration')
resources = app / 'Contents/Resources'
require((resources / 'KurtzThirdPartyNotices.txt').stat().st_size > 10000, 'Bundled third-party notices')
require((resources / 'Assets.car').is_file(), 'Compiled app assets')
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
print('PASS: strict code-signature verification')
result = subprocess.run(['codesign', '-d', '--entitlements', ':-', str(app)], check=True, capture_output=True)
entitlements = plistlib.loads(result.stdout)
require(entitlements.get('com.apple.security.app-sandbox'), 'App Sandbox enabled')
require(entitlements.get('com.apple.security.files.user-selected.read-write'), 'User-selected file access')
require(entitlements.get('com.apple.security.files.bookmarks.app-scope'), 'Persistent scoped bookmarks')
binary = app / 'Contents/MacOS' / info['CFBundleExecutable']
archs = subprocess.check_output(['lipo', '-archs', str(binary)], text=True).split()
if args.universal:
    require({'arm64', 'x86_64'}.issubset(archs), 'Universal Mac executable')
print(f"Verified kurtz {info['CFBundleShortVersionString']} ({info['CFBundleVersion']}): {', '.join(archs)}")
print('Not covered: notarization, Gatekeeper, App Store eligibility or binary license/source obligations.')
