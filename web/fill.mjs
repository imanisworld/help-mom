/**
 * Flood-fill helper for the original, locally hosted seasonal coloring pages.
 * Returns horizontal pixel spans, not bitmaps or image data URLs. The spans
 * remain editable and travel in the existing JSON backup with the drawing.
 */
export const FILL_SIZE = 512;
const MAX_RUNS = 40000;
const isInt = Number.isInteger;
export function validFillRuns(runs) {
  return Array.isArray(runs) && runs.length > 0 && runs.length <= MAX_RUNS
    && runs.every(r => Array.isArray(r) && r.length === 3
      && r.every(isInt) && r[0] >= 0 && r[0] < FILL_SIZE
      && r[1] >= 0 && r[1] < r[2] && r[2] <= FILL_SIZE);
}
/**
 * Fill connected white/light pixels; dark outline pixels are barriers.
 * A 1px dilation of the dark lines helps avoid small anti-aliased gaps.
 * No original artwork or saved stroke is modified.
 */
export function findFillRuns(imageData, px, py) {
  const {width,height,data} = imageData || {};
  if(width !== FILL_SIZE || height !== FILL_SIZE || !data || data.length !== width*height*4)
    throw new Error('Coloring picture could not be read.');
  const sx=Math.floor(px),sy=Math.floor(py);
  if(sx<0||sy<0||sx>=width||sy>=height)throw new Error('Tap inside the picture.');
  const N=width*height, dark=new Uint8Array(N);
  for(let i=0;i<N;i++){
    const j=i*4;
    const r=data[j],g=data[j+1],b=data[j+2],a=data[j+3];
    dark[i]=a>60 && (r*0.299+g*0.587+b*0.114)<175 ? 1:0;
  }
  const blocked=new Uint8Array(dark);
  for(let y=0;y<height;y++)for(let x=0;x<width;x++){
    const i=y*width+x;
    if(!dark[i])continue;
    if(x>0)blocked[i-1]=1;
    if(x<width-1)blocked[i+1]=1;
    if(y>0)blocked[i-width]=1;
    if(y<height-1)blocked[i+width]=1;
  }
  const start=sy*width+sx;
  if(blocked[start])throw new Error('Tap inside a white area, away from a dark outline.');
  const seen=new Uint8Array(N),queue=new Uint32Array(N);
  let front=0,back=0;queue[back++]=start;seen[start]=1;
  while(front<back){
    const id=queue[front++],x=id%width,y=(id-x)/width;
    const neighbors=[x>0?id-1:-1,x<width-1?id+1:-1,y>0?id-width:-1,y<height-1?id+width:-1];
    for(const n of neighbors)if(n>=0 && !blocked[n] && !seen[n]){seen[n]=1;queue[back++]=n}
  }
  const runs=[];
  for(let y=0;y<height;y++){
    const offset=y*width;
    for(let x=0;x<width;){
      if(!seen[offset+x]){x++;continue}
      const first=x++;
      while(x<width && seen[offset+x])x++;
      runs.push([y,first,x]);
      if(runs.length>MAX_RUNS)throw new Error('This area is too detailed to fill. Try a different section.');
    }
  }
  if(!runs.length)throw new Error('No area found to color.');
  return runs;
}
export function includesFillPoint(runs,px,py){
  const x=Math.floor(px),y=Math.floor(py);
  return Array.isArray(runs)&&runs.some(r=>r[0]===y&&r[1]<=x&&x<r[2]);
}
