#!/usr/bin/env node
// Reproducible vector masters, redrawn from the owner's kurtz concept sheet.
// Renderer: npm install --prefix build/rebrand-kurtz/tools @resvg/resvg-js
const fs = require('fs'), path = require('path');
const root = path.resolve(__dirname, '../..');
const { Resvg } = require(path.join(root, 'build/rebrand-kurtz/tools/node_modules/@resvg/resvg-js'));
const C = { graphite: '#1F1F1F', ivory: '#FAF8F1', yellow: '#FFE600' };
const word = [
  'M0 0H27V57L57 30H84L49 64L89 112H55L27 78V112H0Z',
  'M91 30H118V76C118 96 147 96 147 76V30H174V77C174 127 91 127 91 77Z',
  'M181 112V73C181 45 197 30 224 30V56C211 56 208 63 208 77V112Z',
  'M231 7H258V30H281V56H258V76C258 88 264 89 281 89V112H267C242 112 231 98 231 76Z',
  'M288 30H352V50L321 84C331 86 340 93 354 93C365 93 372 88 372 82C372 76 365 75 362 80C358 87 350 85 347 79C341 65 352 56 365 57C384 57 395 72 392 90C389 112 369 124 347 119C329 115 309 104 288 110V88L321 55H288Z'
].map(d => `<path d="${d}"/>`).join('');
// Continuous curl with an open lower-right exit, matching the independent mark.
const curl = '<path d="M99 107H68C79 95 85 86 82 74C79 61 68 54 56 57C47 59 42 66 42 73C42 79 48 81 52 77C58 69 69 75 67 85C65 98 54 105 42 103C21 101 12 84 15 64C19 38 44 23 69 27C96 31 113 53 112 80C112 90 107 100 99 107Z"/>';
const rays = `<g fill="none" stroke="${C.yellow}" stroke-width="9" stroke-linecap="round"><path d="M116 35L123 20M125 45L141 40"/></g>`;
const svg = (w,h,body) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}">${body}</svg>\n`;
function save(p,content) { const f=path.join(root,p);fs.mkdirSync(path.dirname(f),{recursive:true});fs.writeFileSync(f,content); }
function png(p,s,width) { save(p,new Resvg(s,{fitTo:{mode:'width',value:width}}).render().asPng()); }
for(const [mode,ink,bg] of [['dark',C.ivory,C.graphite],['light',C.graphite,C.ivory]]) {
  const mark=svg(160,132,`<g fill="${ink}">${curl}</g>${rays}`);
  const wm=svg(400,128,`<g transform="translate(4 4)" fill="${ink}">${word}</g>`);
  const icon=svg(1024,1024,`<rect width="1024" height="1024" fill="${bg}"/><g transform="translate(196 218) scale(4)"><g fill="${ink}">${curl}</g>${rays}</g>`);
  save(`marketing/brand/kurtz-symbol-${mode}.svg`,mark);
  save(`marketing/brand/kurtz-wordmark-${mode}.svg`,wm);
  save(`marketing/brand/kurtz-icon-${mode}.svg`,icon);
  png(`marketing/brand/kurtz-symbol-${mode}.png`,mark,640);
  png(`marketing/brand/kurtz-wordmark-${mode}.png`,wm,1600);
  png(`marketing/brand/kurtz-icon-${mode}.png`,icon,1024);
  save(`website/assets/kurtz-wordmark-${mode}.svg`,wm);
  const glyph=svg(1024,1024,`<g transform="translate(196 218) scale(4)"><g fill="${ink}">${curl}</g>${rays}</g>`);
  const dir=`Swiftfin/Kurtz/AppIcon-kurtz${mode==='light'?'-light':''}.icon`;
  png(`${dir}/Assets/Glyph.png`,glyph,1024);
  const rgb=mode==='dark'?'0.12157,0.12157,0.12157':'0.98039,0.97255,0.94510';
  save(`${dir}/icon.json`,JSON.stringify({fill:{solid:`srgb:${rgb},1.00000`},groups:[{layers:[{'image-name':'Glyph.png',name:'kurtz'}]}],'supported-platforms':{squares:'shared'}},null,2)+'\n');
  const set=`Swiftfin/Resources/Assets.xcassets/AppIcon-kurtz${mode==='light'?'-light':''}.imageset`;
  png(`${set}/icon.png`,icon,256);
  save(`${set}/Contents.json`,JSON.stringify({images:[{filename:'icon.png',idiom:'universal'}],info:{author:'xcode',version:1}}));
  if(mode==='dark') {
    png('Shared/Resources/Assets.xcassets/KurtzWatermark.imageset/Glyph.png',glyph,1024);
    png('marketing/brand/kurtz-icon.png',icon,256);png('website/assets/kurtz-icon.png',icon,128);
    save('marketing/brand/kurtz-wordmark.svg',wm);save('website/assets/kurtz-wordmark.svg',wm);
  }
}
// Ordinary UI adapts the symbol; video always uses the ivory mark.
const sets='Swiftfin/Resources/Assets.xcassets';
const darkGlyph=fs.readFileSync(path.join(root,'Swiftfin/Kurtz/AppIcon-kurtz.icon/Assets/Glyph.png'));
const lightGlyph=fs.readFileSync(path.join(root,'Swiftfin/Kurtz/AppIcon-kurtz-light.icon/Assets/Glyph.png'));
save(`${sets}/KurtzPlayerMark.imageset/Glyph.png`,fs.readFileSync(path.join(root,'marketing/brand/kurtz-symbol-dark.png')));
save(`${sets}/KurtzPlayerMark.imageset/Contents.json`,JSON.stringify({images:[{filename:'Glyph.png',idiom:'universal'}],info:{author:'xcode',version:1}}));
save(`Shared/Resources/Assets.xcassets/KurtzWatermark.imageset/Glyph-light.png`,lightGlyph);
save(`Shared/Resources/Assets.xcassets/KurtzWatermark.imageset/Contents.json`,JSON.stringify({images:[{filename:'Glyph-light.png',idiom:'universal'},{filename:'Glyph.png',idiom:'universal',appearances:[{appearance:'luminosity',value:'dark'}]}],info:{author:'xcode',version:1}}));
const base='Swiftfin tvOS/Kurtz/KurtzAssets.xcassets/kurtz App Icon & Top Shelf Image.brandassets';
for(const [stack,dimensions] of [['App Icon.imagestack',[[400,240],[800,480]]],['App Icon - App Store.imagestack',[[1280,768]]]]) {
  for(const [w,h] of dimensions)for(const layer of ['back','middle','front']) {
    const scale=h/190;
    const body=layer==='back'?`<rect width="${w}" height="${h}" fill="${C.graphite}"/>`:layer==='middle'?'':`<g transform="translate(${w/2-80*scale} ${h/2-66*scale}) scale(${scale})" fill="${C.ivory}">${curl}${rays}</g>`;
    png(`${base}/${stack}/${layer[0].toUpperCase()+layer.slice(1)}.imagestacklayer/Content.imageset/${layer}-${w}x${h}.png`,svg(w,h,body),w);
  }
}
for(const w of [1920,2320]) {
  const body=`<rect width="${w}" height="720" fill="${C.graphite}"/><g transform="translate(${w/2-400} 218) scale(2)" fill="${C.ivory}">${word}</g><rect x="${w/2-35}" y="510" width="70" height="9" rx="4" fill="${C.yellow}"/>`;
  png(`${base}/Top Shelf Image${w===2320?' Wide':''}.imageset/topshelf-${w}x720.png`,svg(w,720,body),w);
}
save('marketing/brand/tokens.json',JSON.stringify({name:'kurtz',colors:C,font:'Sora',claim:'Good videos go further.'},null,2)+'\n');
console.log('kurtz vector masters, Apple icons, watermark, tvOS layers and website assets generated.');
