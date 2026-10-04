import React from 'react';
import {registerRoot,Composition} from 'remotion';
import {Film} from './Film';
import series from '../series.json';
registerRoot(()=><>{series.map(item=><Composition key={item.id} id={item.id} component={Film} width={1080} height={1920} fps={30} durationInFrames={Math.round(item.duration*30)} defaultProps={{item}}/>)}</>);
