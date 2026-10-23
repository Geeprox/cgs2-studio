.pragma library
// Bounded 2D surface collisions; no fluid solver or per-pixel hit testing.
function random(s){var n=s.seed|0;n^=n<<13;n^=n>>>17;n^=n<<5;s.seed=n;return (n>>>0)/4294967296}
function span(o){return o.type==='circle'?[o.cx-o.r*.9,o.cx+o.r*.9]:[o.x+3,o.x+o.w-3]}
function top(o,x){
 if(o.type==='circle'){var dx=x-o.cx;if(Math.abs(dx)>o.r*.93)return Infinity;return o.cy-Math.sqrt(Math.max(0,o.r*o.r-dx*dx))}
 if(x<o.x||x>o.x+o.w)return Infinity
 var r=o.radius||0,dx=x<o.x+r?x-o.x-r:x>o.x+o.w-r?x-o.x-o.w+r:0
 return o.y+(dx!==0?r-Math.sqrt(Math.max(0,r*r-dx*dx)):0)
}
function normal(o,x){
 if(o.type==='circle'){var dx=(x-o.cx)/o.r;return [dx,-Math.sqrt(Math.max(0,1-dx*dx))]}
 var r=o.radius||0,dx=r?(x<o.x+r?x-o.x-r:x>o.x+o.w-r?x-o.x-o.w+r:0):0
 return dx!==0?[dx/r,-Math.sqrt(Math.max(0,1-dx*dx/(r*r)))]:[0,-1]
}
function hit(surfaces,x0,y0,x1,y1){
 var result=null,best=2
 for(var i=0;i<surfaces.length;i++){
  var o=surfaces[i],a=top(o,x0),b=top(o,x1)
  if(!(y0<=a&&y1>=b)||b===Infinity)continue
  var lo=0,hi=1
  for(var j=0;j<9;j++){var t=(lo+hi)*.5,x=x0+(x1-x0)*t,y=y0+(y1-y0)*t;if(y>=top(o,x))hi=t;else lo=t}
  if(hi<best){best=hi;var xx=x0+(x1-x0)*hi;result={index:i,x:xx,y:top(o,xx),normal:normal(o,xx),t:hi}}
 }return result
}
function bounce(vx,vy,n,restitution){var d=vx*n[0]+vy*n[1];return [vx-(1+restitution)*d*n[0],vy-(1+restitution)*d*n[1]]}
function spawn(s,p,initial){
 var r=random(s);p.x=random(s)*760-20;p.y=initial?random(s)*730-30:-12-r*90
 p.vx=s.kind==='rain'?-28-r*28:5+r*10;p.vy=s.kind==='rain'?300+r*190:29+r*26
 p.size=s.kind==='rain'?12+r*15:1.6+r*2.1;p.alpha=s.kind==='rain'?.27+r*.25:.45+r*.31;p.wobble=random(s)*6.28
}
function create(kind,surfaces,seed){
 var s={kind:kind,surfaces:surfaces,seed:seed||54687,time:0,drops:[],splashes:[],deposits:[],impacts:0,landings:0}
 for(var j=0;j<surfaces.length;j++){var bins=[];for(var k=0;k<17;k++)bins.push(0);s.deposits.push(bins)}
 var count=kind==='rain'?72:kind==='snow'?60:0
 for(var i=0;i<count;i++){var p={};spawn(s,p,true);s.drops.push(p)}return s
}
function deposit(s,h,amount){
 var o=s.surfaces[h.index],range=span(o),u=(h.x-range[0])/(range[1]-range[0]),bins=s.deposits[h.index],bin=Math.max(0,Math.min(16,Math.round(u*16)))
 if(h.normal[1]>-.48)return
 for(var j=-1;j<=1;j++){var i=bin+j;if(i>=0&&i<17)bins[i]=Math.min(5,bins[i]+amount*(j===0?1:.4))}
 s.landings++
}
function step(s,elapsed){
 var dt=Math.max(0,Math.min(.08,elapsed));if(!dt)return;s.time+=dt
 for(var i=0;i<s.drops.length;i++){
  var p=s.drops[i],x=p.x+(p.vx+(s.kind==='snow'?Math.sin(s.time*.8+p.wobble)*9:0))*dt,y=p.y+p.vy*dt
  var h=hit(s.surfaces,p.x,p.y,x,y)
  if(h){
   s.impacts++
   if(s.kind==='rain'){
    var v=bounce(p.vx,p.vy,h.normal,.24),tangent=[-h.normal[1],h.normal[0]]
    for(var q=0;q<2;q++){var sign=q===0?-1:1,life=.27+random(s)*.13;s.splashes.push({x:h.x+h.normal[0]*2,y:h.y+h.normal[1]*2,vx:v[0]*.58+tangent[0]*sign*(18+random(s)*20),vy:v[1]*.58+tangent[1]*sign*24,life:life,total:life,size:1+random(s)*.65})}
    if(s.splashes.length>32)s.splashes.splice(0,s.splashes.length-32)
   }else deposit(s,h,.42+p.size*.16)
   spawn(s,p,false)
  }else{p.x=x;p.y=y;if(y>750||x< -60||x>780)spawn(s,p,false)}
 }
 for(var n=s.splashes.length-1;n>=0;n--){var a=s.splashes[n];a.life-=dt;if(a.life<=0){s.splashes.splice(n,1);continue}a.vy+=560*dt;a.x+=a.vx*dt;a.y+=a.vy*dt}
 if(s.kind==='snow')for(var o=0;o<s.deposits.length;o++){var b=s.deposits[o],copy=b.slice();for(var k=0;k<b.length;k++){var left=copy[Math.max(0,k-1)],right=copy[Math.min(16,k+1)];b[k]=Math.max(0,Math.min(5,copy[k]+((left+right)*.5-copy[k])*.22*dt-.003*dt))}}
}
function protectedPoint(boxes,x,y){for(var i=0;i<boxes.length;i++){var b=boxes[i];if(x>=b[0]&&x<=b[0]+b[2]&&y>=b[1]&&y<=b[1]+b[3])return true}return false}
function insideBody(s,x,y){for(var i=0;i<s.surfaces.length;i++){var o=s.surfaces[i];if(o.type==='circle'){var dx=x-o.cx,dy=y-o.cy;if(dx*dx+dy*dy<o.r*o.r)return true}else if(o.h&&x>=o.x&&x<=o.x+o.w&&y>=top(o,x)&&y<=o.y+o.h)return true}return false}
function draw(c,s,boxes){
 c.lineCap='round';c.lineJoin='round';c.strokeStyle='#d7e9ef';c.fillStyle='#edf5f6'
 for(var i=0;i<s.drops.length;i++){
  var p=s.drops[i];if(protectedPoint(boxes,p.x,p.y)||insideBody(s,p.x,p.y))continue
  c.globalAlpha=p.alpha
  if(s.kind==='rain'){c.lineWidth=1.25;c.beginPath();c.moveTo(p.x-p.vx/p.vy*p.size,p.y-p.size);c.lineTo(p.x,p.y);c.stroke()}
  else{c.beginPath();c.arc(p.x,p.y,p.size,0,Math.PI*2);c.fill()}
 }
 if(s.kind==='snow'){
  c.fillStyle='#e9f3f5';c.globalAlpha=.92
  for(var j=0;j<s.surfaces.length;j++){
   var bins=s.deposits[j],range=span(s.surfaces[j]),sum=0;for(var z=0;z<bins.length;z++)sum+=bins[z];if(sum<.15)continue
   c.beginPath()
   for(var k=0;k<17;k++){var x=range[0]+(range[1]-range[0])*k/16,y=top(s.surfaces[j],x)-bins[k];if(k===0)c.moveTo(x,y);else c.lineTo(x,y)}
   for(var k=16;k>=0;k--){var x=range[0]+(range[1]-range[0])*k/16;c.lineTo(x,top(s.surfaces[j],x)+.65)}c.closePath();c.fill()
  }
 }
 c.fillStyle='#e6f1f5'
 for(var q=0;q<s.splashes.length;q++){var a=s.splashes[q];if(protectedPoint(boxes,a.x,a.y))continue;c.globalAlpha=.75*a.life/a.total;c.beginPath();c.arc(a.x,a.y,a.size,0,Math.PI*2);c.fill()}
 c.globalAlpha=1
}
function summary(s){var max=0,total=0;for(var i=0;i<s.deposits.length;i++)for(var j=0;j<17;j++){max=Math.max(max,s.deposits[i][j]);total+=s.deposits[i][j]}return {drops:s.drops.length,splashes:s.splashes.length,impacts:s.impacts,snowLandings:s.landings,maxSnowPixels:max,snowAmount:total}}
