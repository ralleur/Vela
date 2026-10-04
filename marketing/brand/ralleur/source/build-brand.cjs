/* Native SVG artwork; renderer shared with the kurtz vector build. */
const fs = require('node:fs');
const path = require('node:path');
const {Resvg} = require(path.resolve(__dirname,'../../../../build/rebrand-kurtz/tools/node_modules/@resvg/resvg-js'));
const render = (s,w) => new Resvg(s,{fitTo:{mode:'width',value:w}}).render().asPng();
const root = path.resolve(__dirname, '..');
const bg = '#11151e';
const ink = '#f8f4f1';
const mint = '#77c9b5';
const mono = fs.readFileSync(path.join(root, 'ralleur-monogram.svg'), 'utf8');
const artwork = mono.slice(mono.indexOf('  <g'), mono.lastIndexOf('</svg>'));
const svg = (width, height, body, title='Ralleur') => `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" role="img"><title>${title}</title>${body}</svg>`;
async function exportAsset(name, source, width) {
  fs.writeFileSync(path.join(root, name+'.svg'),source);
  fs.writeFileSync(path.join(root,name+'.png'),render(source,width));
}
(async()=>{
  await exportAsset('ralleur-avatar-lowercase',svg(512,512,`<rect width="512" height="512" fill="${bg}"/>${artwork}`),1024);
  fs.writeFileSync(path.join(root,'ralleur-monogram-transparent.png'),render(mono,1024));
  fs.writeFileSync(path.join(root,'ralleur-video-watermark.png'),render(mono,150));
  const banner = `<rect width="2560" height="1440" fill="${bg}"/>
    <g transform="translate(819 564) scale(.62)">${artwork}</g>
    <text x="1121" y="696" fill="${ink}" font-family="Avenir Next, Arial, sans-serif" font-size="108" font-weight="600" letter-spacing="-4">ralleur</text>
    <text x="1125" y="751" fill="${ink}" font-family="Avenir Next, Arial, sans-serif" font-size="30">Independent apps. Thoughtfully made.</text>
    <text x="1125" y="801" fill="#b9bdc4" font-family="Avenir Next, Arial, sans-serif" font-size="25" letter-spacing="1">kurtz<tspan dx="24" fill="${mint}">/</tspan><tspan dx="24">Hauser</tspan></text>`;
  await exportAsset('ralleur-youtube-banner-lowercase',svg(2560,1440,banner),2560);
  // A review-only mobile crop; never upload this shorter image as the channel banner.
  const preview=svg(2560,1440,banner).replace('viewBox="0 0 2560 1440"','viewBox="508 509 1544 422"').replace('width="2560" height="1440"','width="1544" height="422"');
  fs.writeFileSync(path.join(root,'preview-mobile.png'),render(preview,1544));
  console.log('Exported lowercase r, avatar, transparent mark, watermark, banner and mobile preview.');
})();
