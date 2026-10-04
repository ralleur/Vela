#!/usr/bin/env node
// Compose native typography and vector branding over the retained Imagegen art.
const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'../..');
const {Resvg}=require(path.join(root,'build/rebrand-kurtz/tools/node_modules/@resvg/resvg-js'));
const art=fs.readFileSync(path.join(root,'marketing/dmg/kurtz-background-art.png')).toString('base64');
const word=fs.readFileSync(path.join(root,'marketing/brand/kurtz-wordmark-dark.svg'),'utf8').replace(/<svg[^>]+>|<\/svg>/g,'');
const svg=`<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 1536 1024" width="1536" height="1024">
<image width="1536" height="1024" xlink:href="data:image/png;base64,${art}"/>
<g transform="translate(528 100) scale(1.2)">${word}</g>
<text x="768" y="302" text-anchor="middle" font-family="Sora" font-size="32" fill="#FAF8F1">Good videos go further.</text>
<text x="768" y="878" text-anchor="middle" font-family="Sora" font-size="27" fill="#FAF8F1">Drag kurtz into Applications.</text>
</svg>`;
fs.writeFileSync(path.join(root,'marketing/dmg/background.svg'),svg);
fs.writeFileSync(path.join(root,'marketing/dmg/background@2x.png'),new Resvg(svg,{font:{fontFiles:[path.join(root,'Shared/Resources/Fonts/Sora-Regular.ttf')],loadSystemFonts:false}}).render().asPng());
console.log('Composed 1536×1024 kurtz installer background.');
