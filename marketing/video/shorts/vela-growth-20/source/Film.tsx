import React from 'react';
import {AbsoluteFill,Img,OffthreadVideo,Sequence,staticFile,useCurrentFrame,interpolate} from 'remotion';
import './style.css';
const cap={extrapolateLeft:'clamp',extrapolateRight:'clamp'} as const;
const p=(f:number,a:number,b:number)=>interpolate(f,[a,b],[0,1],cap);
const smooth=(x:number)=>1-Math.pow(1-x,3);
const fill:React.CSSProperties={width:'100%',height:'100%',objectFit:'cover',display:'block'};
const Still=({name,style={}}:{name:string;style?:React.CSSProperties})=><Img src={staticFile('shots/'+name+'.jpg')} style={{...fill,...style}}/>;
const Play=({server=false,trim=0,style={}}:{server?:boolean;trim?:number;style?:React.CSSProperties})=><OffthreadVideo muted src={staticFile('media/'+(server?'jellyfin':'local')+'.mp4')} trimBefore={Math.round(trim*30)} style={{...fill,...style}}/>;
const Card=({children,tall=false,style={}}:{children:React.ReactNode;tall?:boolean;style?:React.CSSProperties})=>{
 const f=useCurrentFrame();return <div className={'card'+(tall?' tall':'')} style={{transform:`translateY(${-12*p(f,0,90)}px) scale(${1+.018*p(f,0,90)})`,...style}}>{children}</div>;
};
const Player=({server=false,clean=false}:{server?:boolean;clean?:boolean})=><Card style={{height:650,top:660}}>{clean?<Still name="player-clean" style={{objectFit:'contain'}}/>:<Play server={server}/>}<div className="source-badge">{server?'JELLYFIN':'LOCAL VIDEO'}</div></Card>;
const Pair=()=>{
 const f=useCurrentFrame();const k=smooth(p(f,0,36));
 return <><Card style={{top:610,height:360,transform:`perspective(1800px) rotateY(${-8*(1-k)}deg) translateX(${-40*(1-k)}px)`}}><Still name="local-workflow" style={{objectFit:'contain'}}/><div className="source-badge">YOUR FILES</div></Card><Card style={{top:1010,height:470,transform:`perspective(1800px) rotateY(${8*(1-k)}deg) translateX(${40*(1-k)}px)`}}><Still name="jellyfin-home" style={{objectPosition:'50% 0%'}}/><div className="source-badge">YOUR JELLYFIN LIBRARY</div></Card></>;
};
const Controls=({compare=true}:{compare?:boolean})=>{
 const f=useCurrentFrame(),k=compare?smooth(p(f,18,36)):0;
 return <Card style={{height:710,top:620}}><div style={{position:'absolute',inset:0,overflow:'hidden'}}><Still name="player-controls" style={{objectFit:'cover',objectPosition:'74% 50%'}}/><AbsoluteFill style={{clipPath:`inset(0 ${100*(1-k)}% 0 0)`}}><Still name="player-clean" style={{objectPosition:'74% 50%'}}/></AbsoluteFill>{k>0&&k<1?<div className="compare-line" style={{left:`${k*100}%`}}/>:null}</div><div className="source-badge">{compare?(k<.5?'WITH CONTROLS':'WITHOUT CONTROLS'):'PLAYBACK CONTROLS'}</div></Card>;
};
const Library=({detail=false}:{detail?:boolean})=><Card tall><Still name={detail?'jellyfin-detail':'jellyfin-home'} style={{objectFit:'contain'}}/><div className="source-badge">YOUR JELLYFIN SERVER</div></Card>;
const Subtitle=({add=false}:{add?:boolean})=>{
 const f=useCurrentFrame();
 return <Card tall><Still name="subtitles" style={{position:'absolute',width:1920,height:1541,left:-1110,top:-140,maxWidth:'none'}}/>{add?<div className="callout" style={{left:15,top:688,width:395,height:56,opacity:p(f,10,18)}}/>:null}</Card>;
};
const Visual=({beat,item}:{beat:any;item:any})=>{
 const f=useCurrentFrame(),v=beat.visual;
 if(v==='pair')return <Pair/>;
 if(v==='sourceSwitch')return f<30?<Card><Still name="local-workflow"/><div className="source-badge">LOCAL FILE</div></Card>:f<60?<Sequence from={30}><Library/></Sequence>:<Sequence from={60}><Player server/></Sequence>;
 if(v==='controls')return <Controls/>;
 if(v==='controlsStill')return <Controls compare={false}/>;
 if(v==='clean')return <Player clean/>;
 if(v==='library'||v==='libraryHook')return <Library/>;
 if(v==='detail')return <Library detail/>;
 if(v==='subtitles'||v==='subtitleAdd')return <Subtitle add={v==='subtitleAdd'}/>;
 if(v==='file')return <Card style={{height:510,top:710}}><Still name="local-workflow" style={{objectFit:'contain'}}/><div className="source-badge">OPEN VIDEO · MAC</div></Card>;
 if(v==='filePlay'||v==='keyboard')return <>{f<36?<Card style={{height:510,top:710}}><Still name="local-workflow" style={{objectFit:'contain'}}/></Card>:<Sequence from={36}><Player/></Sequence>}{v==='keyboard'?<div className="key">⌘ O</div>:<div className="key small-key">Sintel.mkv</div>}</>;
 if(v==='keyboardStill')return <><Card style={{height:510,top:710}}><Still name="local-workflow" style={{objectFit:'contain'}}/></Card><div className="key">⌘ O</div></>;
 if(v==='price'||v==='free')return <><Player/><div className="price" style={{opacity:v==='free'?1:p(f,18,24),transform:`translateY(${20*(1-p(f,18,24))}px)`}}>{v==='free'?'Free.':item.id==='V09'?'No Pro tier.':item.id==='V16'?'The whole app.':'Free.'}</div></>;
 if(v==='upstream')return <><Library/><div className="lineage" style={{opacity:p(f,0,18)}}><span>Swiftfin</span><b>→</b><Img src={staticFile('brand/vela-wordmark.svg')}/></div></>;
 if(v==='vlc')return <><Player/><div className="key small-key" style={{opacity:p(f,16,30)}}>JUST PLAY THE FILE.</div></>;
 if(v==='full')return <Card style={{top:570,height:900}}><Play style={{objectFit:'cover',objectPosition:'65% 50%'}}/></Card>;
 return <Player server={v==='server'}/>;
};
const Beat=({beat,item,index}:{beat:any;item:any;index:number})=>{
 const f=useCurrentFrame();
 const maximum=Math.max(...beat.text.map((t:string)=>t.length));
 const size=maximum>24?68:maximum>21?76:maximum>18?85:maximum>15?95:110;
 const localLabel=['V04','V06','V15'].includes(item.id);
 return <AbsoluteFill>
  <div className="background"><Still name={['library','pair','upstream'].includes(beat.visual)?'jellyfin-home':'player-clean'}/></div>
  <div className="eyebrow">FOR MAC{localLabel?' · LOCAL VIDEO':''}</div>
  <div className="headline" style={{fontSize:size,transform:`translateY(${index===0?0:12*(1-smooth(p(f,0,8)))}px)`}}>{beat.text.map((line:string,i:number)=><div key={i} className={i===beat.text.length-1?'accent':''}>{line}</div>)}</div>
  <Visual beat={beat} item={item}/>
  {!beat.cta?<div className="micro-brand" style={{opacity:index?1:p(f,55,68)}}><Img src={staticFile('brand/vela-wordmark.svg')}/><span>Free Mac app · Beta</span></div>:<div className="cta"><Img src={staticFile('brand/vela-wordmark.svg')}/><div>Free Mac beta<span>ralleur.github.io/Vela</span></div></div>}
  {beat.footnote?<div className="footnote">{beat.footnote}</div>:null}
  <div className="credits">Demo films: Blender Foundation &amp; Caminandes team<br/>CC BY / BY-SA 3.0 · Full credits in description</div>
 </AbsoluteFill>;
};
export const Film=({item}:{item:any})=><AbsoluteFill className="film">{item.beats.map((beat:any,index:number)=><Sequence key={index} from={Math.round(beat.start*30)} durationInFrames={Math.round(beat.duration*30)}><Beat beat={beat} item={item} index={index}/></Sequence>)}</AbsoluteFill>;
