import {bundle} from '@remotion/bundler';
import {getCompositions,renderMedia,renderStill,openBrowser} from '@remotion/renderer';
import {readFileSync,mkdirSync,existsSync,rmSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import path from 'node:path';
const root=path.dirname(new URL(import.meta.url).pathname),dest=path.resolve(root,'../exports/vela-shorts-en');
process.chdir(root);
const items=JSON.parse(readFileSync(path.join(root,'series.json'))),mode=process.argv[2]||'render',ids=process.argv.slice(3);
mkdirSync(path.join(root,'out'),{recursive:true});rmSync(path.join(root,'out/bundle'),{recursive:true,force:true});
const serveUrl=await bundle({entryPoint:path.join(root,'src/index.tsx'),publicDir:path.join(root,'public'),outDir:path.join(root,'out/bundle')});
const browser=await openBrowser('chrome');
try{const comps=await getCompositions(serveUrl,{puppeteerInstance:browser});
for(const item of items.filter(x=>!ids.length||ids.includes(x.id))){const composition=comps.find(c=>c.id===item.id);
if(mode==='stills'){for(const frame of [0,36,75])await renderStill({serveUrl,composition,frame,output:path.join(root,'out',`${item.id}-${frame}.png`),puppeteerInstance:browser,logLevel:'error'});console.log(item.id+' hooks');continue;}
const final=path.join(dest,item.file);if(existsSync(final)){console.log(item.id+' exists');continue;}
const raw=path.join(root,'out',item.id+'-silent.mp4');let last=-1;
if(!existsSync(raw))await renderMedia({serveUrl,composition,codec:'h264',crf:17,pixelFormat:'yuv420p',outputLocation:raw,concurrency:6,puppeteerInstance:browser,logLevel:'error',onProgress:({progress})=>{let n=Math.floor(progress*4);if(n>last){last=n;console.log(item.id+' '+n*25+'%');}}});
execFileSync('ffmpeg',['-y','-v','error','-i',raw,'-ss',String(item.musicOffset),'-i',path.join(root,'public/music',item.music),'-map','0:v:0','-map','1:a:0','-t',String(item.duration),'-vf','scale=in_range=pc:out_range=tv:in_color_matrix=bt601:out_color_matrix=bt709','-c:v','libx264','-crf','18','-preset','fast','-threads','2','-pix_fmt','yuv420p','-colorspace','bt709','-color_primaries','bt709','-color_trc','bt709','-color_range','tv','-af',`afade=t=in:st=0:d=0.02,afade=t=out:st=${item.duration-.35}:d=0.35,loudnorm=I=-14:TP=-1.5:LRA=9`,'-c:a','aac','-b:a','256k','-ar','48000','-metadata','title='+item.title,'-metadata','comment=Vela Mac beta. Original captures. Composition CC BY-SA 3.0; film and music credits accompany the upload description.','-movflags','+faststart',final],{stdio:'inherit'});
console.log('DONE '+item.file);
}}finally{await browser.close({silent:true});}
