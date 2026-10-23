.pragma library
// Same bounded 2D renderer is used by native Qt and the browser preview.
function project(u,v,t){return [24+672*u+1.5*Math.sin(v*18+t*.8+u*5),24+672*v+1.4*Math.sin(u*20-t*.65+v*3)]}
function drawBase(c,w,h){
 var t=0;
 c.save();c.scale(w/720,h/720);c.clearRect(0,0,720,720);
 var g=c.createLinearGradient(0,0,600,720);g.addColorStop(0,'#075b7a');g.addColorStop(.48,'#139fbb');g.addColorStop(1,'#67cdd1');c.fillStyle=g;c.fillRect(0,0,720,720);
 c.lineWidth=1.05;c.strokeStyle='rgba(198,235,226,.20)';
 for(var i=0;i<=30;i++){c.beginPath();for(var j=0;j<=30;j++){var p=project(i/30,j/30,t);if(j===0)c.moveTo(p[0],p[1]);else c.lineTo(p[0],p[1])}c.stroke()}
 for(var j=0;j<=30;j++){c.beginPath();for(var i=0;i<=30;i++){var p=project(i/30,j/30,t);if(i===0)c.moveTo(p[0],p[1]);else c.lineTo(p[0],p[1])}c.stroke()}
 var light=c.createRadialGradient(570,185,10,550,240,510);light.addColorStop(0,'rgba(211,255,230,.25)');light.addColorStop(1,'rgba(211,255,230,0)');c.fillStyle=light;c.fillRect(0,0,720,720);
 // Equal-width walls surround the water: a strictly vertical overhead camera.
 c.fillStyle='rgba(0,37,65,.27)';c.fillRect(0,0,720,24);c.fillRect(0,0,24,720);
 c.fillStyle='rgba(185,230,214,.18)';c.fillRect(696,0,24,720);c.fillRect(0,696,720,24);
 c.strokeStyle='rgba(213,243,223,.35)';c.lineWidth=2;c.strokeRect(24,24,672,672);
 var shade=c.createLinearGradient(0,0,0,210);shade.addColorStop(0,'rgba(0,34,55,.48)');shade.addColorStop(1,'rgba(0,34,55,0)');c.fillStyle=shade;c.fillRect(0,0,720,220);
 c.restore();
}
function drawRipples(c,t,w,h){
 c.save();c.scale(w/720,h/720);c.clearRect(0,0,720,720);c.lineWidth=2.4;
 for(var group=0;group<3;group++){
  c.beginPath();
  for(var n=group;n<36;n+=3){
   var cx=44+(n%6)*127+18*Math.sin(n*2.71),cy=38+Math.floor(n/6)*128+17*Math.cos(n*1.83),pts=[];
   for(var k=0;k<8;k++){var a=k*Math.PI/4,r=58+13*Math.sin(k*1.71+n*2.4+t*.4)+8*Math.sin(k*2.8-n+t*.8);pts.push([cx+Math.cos(a)*r,cy+Math.sin(a)*r*.85])}
   c.moveTo((pts[7][0]+pts[0][0])/2,(pts[7][1]+pts[0][1])/2);
   for(var k=0;k<8;k++){var q=pts[(k+1)%8];c.quadraticCurveTo(pts[k][0],pts[k][1],(pts[k][0]+q[0])/2,(pts[k][1]+q[1])/2)}
   c.closePath();
  }
  c.strokeStyle='rgba(218,255,240,'+(.095+group*.045)+')';c.stroke();
 }
 c.restore();
}
function draw(c,t,w,h){drawBase(c,w,h);drawRipples(c,t,w,h)}
// Visible caustic motion without repeatedly decoding a full-screen frame sequence.
// The same pure transform function drives the QML surface and offline verification.
// 840 at the native 720 viewport: even the smallest scale plus maximum drift
// leaves every image edge outside the screen, so no inner floor-shaped patch.
function surfaceExtent(w,h){return Math.max(w,h)*7/6}
function wrapTime(seconds){return ((seconds%12)+12)%12}
function motion(seconds){
 var t=wrapTime(seconds)/12*Math.PI*2;
 return {ax:26*Math.sin(t),ay:19*Math.cos(t),as:1+.022*Math.sin(t*2),ao:.88+.10*Math.sin(t),
         bx:21*Math.cos(t),by:27*Math.sin(t),bs:1.04+.025*Math.cos(t*2),bo:.40+.12*Math.cos(t)};
}
// Shared wave phase; each buoy receives a different phase offset from PoolFace.
function buoy(phase){return {x:13*Math.sin(phase)+3*Math.sin(phase*2+.8),y:17*Math.cos(phase*2)+3*Math.sin(phase-.6),roll:3.2*Math.sin(phase*2+.4)+.8*Math.sin(phase)}}
