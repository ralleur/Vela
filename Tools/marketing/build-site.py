#!/usr/bin/env python3
"""Validate and stage the dependency-free GitHub Pages site. Python stdlib only."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit, unquote
import shutil
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'website'
OUT=ROOT/'build/site'
class Page(HTMLParser):
    def __init__(self):
        super().__init__();self.urls=[];self.ids=set();self.images=[];self.h1=0
    def handle_starttag(self,tag,attrs):
        a=dict(attrs)
        if 'id' in a:
            assert a['id'] not in self.ids, f'Duplicate id: {a["id"]}'
            self.ids.add(a['id'])
        if tag=='h1':self.h1+=1
        if tag=='img':self.images.append(a)
        for k in ('href','src','poster'):
            if k in a:self.urls.append(a[k])
        if 'srcset' in a:self.urls += [s.strip().split()[0] for s in a['srcset'].split(',')]
pages={}
for path in SOURCE.glob('*.html'):
    p=Page();p.feed(path.read_text());pages[path]=p
    assert p.h1==1, f'{path}: needs one h1'
    for im in p.images:
        assert all(k in im for k in ('alt','width','height')), f'{path}: image metadata missing {im}'
for path,p in pages.items():
    for url in p.urls:
        u=urlsplit(url)
        if u.scheme or u.netloc:continue
        assert not u.path.startswith('/'), f'Root-relative path breaks /kurtz/: {url}'
        target=(path.parent/unquote(u.path)).resolve() if u.path else path
        if target.is_dir():target/='index.html'
        assert target.is_relative_to(SOURCE.resolve()), f'Link escapes website: {url}'
        assert target.is_file(), f'{path.name}: missing {url}'
        if u.fragment and target in pages:assert u.fragment in pages[target].ids, f'Missing anchor {url}'
for path in SOURCE.rglob('*'):
    if path.is_file():
        assert path.stat().st_size < 2_000_000, f'Oversize site asset: {path}'
assert sum(p.stat().st_size for p in SOURCE.rglob('*') if p.is_file()) < 8_000_000, 'Site exceeds 8 MB total budget'
if OUT.exists():shutil.rmtree(OUT)
shutil.copytree(SOURCE,OUT)
(OUT/'.nojekyll').touch()
print(f'Validated {len(pages)} pages. Staged {sum(1 for p in OUT.rglob("*") if p.is_file())} files in {OUT}')
