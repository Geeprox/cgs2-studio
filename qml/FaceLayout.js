.pragma library
var keys=['airPM25','airCO2','airTVOC','airNoise','airTEMP','airHUMI','airPM10'];
function clamp(n,a,b){return Math.max(a,Math.min(b,n))}
function number(n,a,b){return typeof n==='number'&&isFinite(n)&&n>=a&&n<=b}
function clean(theme,v){
 if(!v||typeof v!=='object')return null;
 var out={items:{}};
 for(var i=0;i<keys.length;i++){
  var k=keys[i],s=v.items&&v.items[k];if(!s)continue;
  if(!number(s.cx,60,660)||!number(s.cy,60,640))continue;
  if(String(theme)==='7'){out.items[k]={cx:s.cx,cy:s.cy};continue}
  if(String(theme)!=='5'&&String(theme)!=='12'||!number(s.z,-120,420)||!number(s.rx,-35,35)||!number(s.ry,-55,55)||!number(s.rz,-30,30))continue;
  out.items[k]={cx:s.cx,cy:s.cy,z:s.z,rx:s.rx,ry:s.ry,rz:s.rz};
  if(number(s.slot,0,6)&&Math.floor(s.slot)===s.slot)out.items[k].slot=s.slot;
 }
 if((String(theme)==='5'||String(theme)==='12')&&v.view&&number(v.view.yaw,-18,18)&&number(v.view.pitch,-14,14))out.view={yaw:v.view.yaw,pitch:v.view.pitch};
 return String(theme)==='7'||String(theme)==='5'||String(theme)==='12'?out:null;
}
function poolPosition(x,y,primary){var cx=clamp(x,primary?102:82,primary?618:638);return {cx:cx,cy:clamp(y,primary?(cx>290?310:282):262,primary?548:584)}}
// The released buoy owns its landing point. Only its neighbours may be displaced.
function settlePool(key,x,y,items,primaryKey){return poolPosition(x,y,key===primaryKey)}
function dropPool(key,x,y,items,primaryKey){
 var out=JSON.parse(JSON.stringify(items)),land=poolPosition(x,y,key===primaryKey);out[key]=land;
 function radius(k){return k===primaryKey?96:70}
 var names=Object.keys(out);
 for(var pass=0;pass<90;pass++){
  var worst=0;
  for(var i=0;i<names.length;i++)for(var j=i+1;j<names.length;j++){
   var a=names[i],b=names[j],p=out[a],q=out[b],dx=q.cx-p.cx,dy=q.cy-p.cy,d=distance(dx,dy),gap=radius(a)+radius(b)+8-d;
   if(gap<=.3)continue;worst=Math.max(worst,gap);
   if(d<.01){dx=Math.cos((i*7+j)*2.4);dy=Math.sin((i*7+j)*2.4);d=1}
   var shift=gap+1,share=a===key?0:b===key?1:.5;
   if(a!==key)out[a]=poolPosition(p.cx-dx/d*shift*share,p.cy-dy/d*shift*share,a===primaryKey);
   if(b!==key)out[b]=poolPosition(q.cx+dx/d*shift*(1-share),q.cy+dy/d*shift*(1-share),b===primaryKey);
  }
  out[key]=land;if(worst<.5)break;
 }
 // Resolve boundary traps by moving a neighbour to its nearest available spot.
 for(var round=0;round<3;round++)for(var i=0;i<names.length;i++){
  var k=names[i];if(k===key)continue;var original=out[k],best=original,score=1e20;
  for(var r=0;r<=600;r+=12){
   for(var n=0;n<(r===0?1:48);n++){
    var t=n/48*Math.PI*2,c=poolPosition(original.cx+r*Math.cos(t),original.cy+r*Math.sin(t),k===primaryKey),penalty=0;
    for(var j=0;j<names.length;j++){var other=names[j];if(other===k)continue;var o=out[other],gap=radius(k)+radius(other)+8-distance(c.cx-o.cx,c.cy-o.cy);if(gap>0)penalty+=gap*gap*(other===key?100:1)}
    var cost=penalty*1000+distance(c.cx-original.cx,c.cy-original.cy);
    if(cost<score){score=cost;best=c}
   }
   if(score<r+12)break;
  }out[k]=best;
 }out[key]=land;return out;
}
function distance(x,y){return Math.sqrt(x*x+y*y)}
