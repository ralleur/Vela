#!/usr/bin/env node
// Editorial social card: native vector identity + unmodified current app capture.
const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'../..');
const {Resvg}=require(path.join(root,'build/rebrand-kurtz/tools/node_modules/@resvg/resvg-js'));
const mark=fs.readFileSync(path.join(root,'marketing/brand/kurtz-wordmark-dark.svg'),'utf8').replace('<svg ','<svg x="54" y="42" ');
const capture=fs.readFileSync(path.join(root,'marketing/screenshots/kurtz-0.9.6/player-clean.jpg')).toString('base64');
const svg=`<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1200" height="630" viewBox="0 0 1200 630"><rect width="1200" height="630" fill="#1F1F1F"/><g transform="scale(.65)">${mark}</g><g font-family="Sora" fill="#FAF8F1"><text x="54" y="246" font-size="66" font-weight="700">Good videos.</text><text x="54" y="321" font-size="66" font-weight="700">Go further.</text><text x="57" y="380" font-size="21">Your files. Your Jellyfin library.</text><text x="57" y="416" font-size="21">Free &amp; open source.</text><text x="57" y="531" fill="#FFE600" font-size="19" font-weight="600">kurtz 0.9.6 · Mac beta</text><text x="57" y="589" fill="#C4C2BB" font-size="13">Sintel © Blender Foundation / durian.blender.org · CC BY 3.0</text></g><image x="598" y="194" width="552" height="257" xlink:href="data:image/jpeg;base64,${capture}"/><path d="M57 462H116" stroke="#FFE600" stroke-width="6" stroke-linecap="round"/></svg>`;
fs.writeFileSync(path.join(root,'marketing/brand/kurtz-social-preview.svg'),svg);
const png=new Resvg(svg,{font:{fontFiles:['Sora-Regular.ttf','Sora-Bold.ttf','Sora-SemiBold.ttf'].map(f=>path.join(root,'Shared/Resources/Fonts',f)),loadSystemFonts:false}}).render().asPng();
fs.writeFileSync(path.join(root,'marketing/brand/kurtz-social-preview.png'),png);
console.log('kurtz social vector master and PNG exported.');
