.pragma library
// Parallel projection, with opposing standing planes and one low horizontal plane.
// Standing planes solve rx from ry/rz so their front verticals stay vertical.
// Scale, placement and line weight are art directed separately; depth has no
// perspective magnification or common vanishing point.
var camera={x:360,y:336,focal:530};
function upright(ry,rz){return Math.atan(Math.tan(rz*Math.PI/180)/Math.sin(ry*Math.PI/180))*180/Math.PI}
function plate(cx,cy,w,h,z,depth,rx,ry,rz,stroke,echo,kind){return {cx:cx,cy:cy,w:w,h:h,z:z,rx:rx,ry:ry,rz:rz,depth:depth,strokeWeight:stroke,echoWeight:echo,kind:kind||'metric'}}
var primary=plate(210,319,350,235,-35,2,upright(35,-21),35,-21,1.8,1.1,'primary');
var instruments=[
 plate(140,148,200,132,90,1,upright(35,-21),35,-21,1.8,1.0),
 plate(365,139,160,108,280,0,upright(-34,21),-34,21,4.6,1.5),
 plate(576,162,215,152,115,1,upright(35,-21),35,-21,2.8,1.1),
 plate(135,556,194,130,105,1,upright(-34,21),-34,21,3.6,1.2),
 plate(365,568,195,150,285,0,35,55,-24,1.8,1.1),
 plate(624,310,132,92,310,0,upright(-34,21),-34,21,2.6,1.0)
];
var slots=[primary].concat(instruments);
var clock=plate(516,443,352,168,-65,2,upright(-35,21),-35,21,4.0,1.4,'clock');
var seconds=plate(420,268,94,68,260,0,upright(-34,21),-34,21,1.8,1.0,'seconds');
var keys=['airPM25','airCO2','airTVOC','airNoise','airTEMP','airHUMI','airPM10'];
function copy(v){return JSON.parse(JSON.stringify(v))}
function clamp(n,a,b){return Math.max(a,Math.min(b,n))}
function cameraView(v){return {yaw:clamp(v&&isFinite(v.yaw)?v.yaw:0,-14,14),pitch:clamp(v&&isFinite(v.pitch)?v.pitch:0,-9,9)}}
function sameAxes(s,slot){var a=slots[slot];return s&&a&&s.rx===a.rx&&s.ry===a.ry&&s.rz===a.rz}
function constrain(s,slot){
 var a=slots[slot],n=copy(a);n.slot=slot;
 // Each slot keeps its own authored plane; a drag changes position and depth.
 n.cx=clamp(isFinite(s.cx)?s.cx:a.cx,Math.max(60,a.cx-(slot===0?38:44)),Math.min(660,a.cx+(slot===0?38:44)));
 n.cy=clamp(isFinite(s.cy)?s.cy:a.cy,Math.max(60,a.cy-34),Math.min(640,a.cy+34));
 n.z=clamp(isFinite(s.z)?s.z:a.z,Math.max(-120,a.z-45),Math.min(420,a.z+45));
 return n;
}
function layout(primaryKey,items){
 var out={},used={0:true},pending=[],main=keys.indexOf(primaryKey)>=0?primaryKey:keys[0],saved=items&&items[main];
 out[main]=constrain(saved&&saved.slot===0&&sameAxes(saved,0)?saved:primary,0);
 for(var i=0;i<keys.length;i++)if(keys[i]!==main){var k=keys[i],s=items&&items[k],slot=s&&s.slot;
  if(slot>=1&&slot<=6&&slot===Math.floor(slot)&&!used[slot]){out[k]=constrain(sameAxes(s,slot)?s:slots[slot],slot);used[slot]=true}else pending.push(k)
 }
 var next=1;for(var j=0;j<pending.length;j++){while(used[next])next++;out[pending[j]]=constrain(slots[next],next);used[next]=true}
 return out;
}
function select(items,oldKey,newKey){
 var p=copy(items),old=p[oldKey],chosen=p[newKey];if(!old||!chosen)return layout(newKey,p);
 p[oldKey]=constrain(slots[chosen.slot],chosen.slot);p[newKey]=constrain(primary,0);return layout(newKey,p);
}
function layerCount(s){return s.depth===2?4:s.depth===1?3:2}
function readingRects(s){
 if(s.kind==='clock')return [{x:9,y:9,w:s.w-18,h:s.h-18,role:'value'}];
 if(s.kind==='seconds')return [{x:7,y:2,w:s.w-14,h:s.h-4,role:'value'}];
 if(s.kind==='primary'||s.slot===0)return [{x:(s.w-160)/2,y:7,w:160,h:32,role:'label'},{x:(s.w-120)/2,y:42,w:120,h:22,role:'unit'},{x:12,y:69,w:s.w-24,h:s.h-75,role:'value'}];
 var labelH=Math.min(26,s.h*.2),unitH=Math.min(20,Math.max(16,s.h*.15)),valueY=labelH+10,unitY=s.h-8-unitH;
 return [{x:(s.w-Math.min(112,s.w-20))/2,y:5,w:Math.min(112,s.w-20),h:labelH,role:'label'},{x:10,y:valueY,w:s.w-20,h:unitY-8-valueY,role:'value'},{x:(s.w-Math.min(114,s.w-20))/2,y:unitY,w:Math.min(114,s.w-20),h:unitH,role:'unit'}];
}
function textPolygons(s,view){
 var m=matrix(s,0,view),rects=readingRects(s),polys=[];
 for(var i=0;i<rects.length;i++){var a=rects[i],p=[],pad=s.kind==='primary'||s.slot===0?4:2,x=a.x-pad,y=a.y-pad,w=a.w+pad*2,h=a.h+pad*2;
  for(var c=0;c<4;c++){var xx=x+(c===1||c===2?w:0),yy=y+(c>=2?h:0);p.push([m[0]*xx+m[1]*yy+m[3],m[4]*xx+m[5]*yy+m[7]])}polys.push(p)
 }return polys;
}
function separation(a,b){
 var best=-1e9;
 for(var shape=0;shape<2;shape++){var q=shape?b:a;
  for(var i=0;i<q.length;i++){var edgeX=q[(i+1)%q.length][0]-q[i][0],edgeY=q[(i+1)%q.length][1]-q[i][1],len=Math.sqrt(edgeX*edgeX+edgeY*edgeY),nx=-edgeY/len,ny=edgeX/len,amin=1e9,amax=-1e9,bmin=1e9,bmax=-1e9;
   for(var j=0;j<a.length;j++){var d=a[j][0]*nx+a[j][1]*ny;amin=Math.min(amin,d);amax=Math.max(amax,d)}
   for(var k=0;k<b.length;k++){var e=b[k][0]*nx+b[k][1]*ny;bmin=Math.min(bmin,e);bmax=Math.max(bmax,e)}
   best=Math.max(best,amin-bmax,bmin-amax)
  }
 }return best;
}
function polygonBounds(polys){var left=1e9,right=-1e9,top=1e9,bottom=-1e9;for(var i=0;i<polys.length;i++)for(var c=0;c<polys[i].length;c++){var p=polys[i][c];left=Math.min(left,p[0]);right=Math.max(right,p[0]);top=Math.min(top,p[1]);bottom=Math.max(bottom,p[1])}return {left:left,right:right,top:top,bottom:bottom}}
function boxGap(a,b){return Math.max(a.left-b.right,b.left-a.right,a.top-b.bottom,b.top-a.bottom)}
function clear(items,view){
 var groups=[];for(var key in items)groups.push(textPolygons(items[key],view));groups.push(textPolygons(clock,view));groups.push(textPolygons(seconds,view));
 var boxes=[];for(var i=0;i<groups.length;i++){var bounds=polygonBounds(groups[i]);boxes.push(bounds);if(bounds.left<22||bounds.right>698||bounds.top<62||bounds.bottom>638)return false;
  for(var j=0;j<i;j++){
   // Broad phase only skips distant text. Overlapping rectangles proceed to SAT.
   if(boxGap(bounds,boxes[j])>=6)continue;
   for(var a=0;a<groups[i].length;a++)for(var b=0;b<groups[j].length;b++)if(separation(groups[i][a],groups[j][b])<6)return false;
  }
 }return true;
}
function interpolate(a,b,t){var out=copy(a);for(var k in b)if(typeof b[k]==='number')out[k]=a[k]+(b[k]-a[k])*t;return out}
function safeMove(items,key,start,dx,dy,view){
 var proposed=constrain(move(start,dx,dy,view),start.slot),out=copy(items);out[key]=proposed;if(clear(out,view))return proposed;
 // Constrain actual text quadrilaterals; empty corners and depth rails may overlap.
 var lo=0,hi=1;for(var i=0;i<9;i++){var m=(lo+hi)/2;out[key]=interpolate(start,proposed,m);if(clear(out,view))lo=m;else hi=m}return interpolate(start,proposed,lo);
}
function safeView(items,current,candidate){var v=cameraView(candidate);if(clear(items,v))return v;var lo=0,hi=1;for(var i=0;i<9;i++){var m=(lo+hi)/2;if(clear(items,interpolate(current,v,m)))lo=m;else hi=m}return interpolate(current,v,lo)}
function restore(primaryKey,items,view){var p=layout(primaryKey,items),v=cameraView(view);if(clear(p,v))return {items:p,view:v};p=layout(primaryKey,null);v=safeView(p,{yaw:0,pitch:0},v);return {items:p,view:v}}
function rotation(rx,ry,rz){rx*=Math.PI/180;ry*=Math.PI/180;rz*=Math.PI/180;var sx=Math.sin(rx),cx=Math.cos(rx),sy=Math.sin(ry),cy=Math.cos(ry),sz=Math.sin(rz),cz=Math.cos(rz);return [cz*cy,cz*sy*sx-sz*cx,cz*sy*cx+sz*sx,sz*cy,sz*sy*sx+cz*cx,sz*sy*cx-cz*sx,-sy,cy*sx,cy*cx]}
function mul(r,p){return [r[0]*p[0]+r[1]*p[1]+r[2]*p[2],r[3]*p[0]+r[4]*p[1]+r[5]*p[2],r[6]*p[0]+r[7]*p[1]+r[8]*p[2]]}
function geometry(s,layer,view){
 var r=rotation(s.rx,s.ry,s.rz),g=rotation(view?view.pitch:0,view?view.yaw:0,0),depth=(layer||0)*22;
 var c=mul(g,[s.cx-camera.x+r[2]*depth,s.cy-camera.y+r[5]*depth,s.z-100+r[8]*depth]);
 return {c:c,u:mul(g,[r[0],r[3],r[6]]),v:mul(g,[r[1],r[4],r[7]])};
}
function matrix(s,layer,view){var g=geometry(s,layer,view),u=g.u,v=g.v;return [u[0],v[0],0,g.c[0]+camera.x-u[0]*s.w/2-v[0]*s.h/2,u[1],v[1],0,g.c[1]+camera.y-u[1]*s.w/2-v[1]*s.h/2,0,0,1,0,0,0,0,1]}
function point(s,x,y,layer,view){var m=matrix(s,layer||0,view);return [m[0]*x+m[1]*y+m[3],m[4]*x+m[5]*y+m[7]]}
function quad(s,view){return [point(s,0,0,0,view),point(s,s.w,0,0,view),point(s,s.w,s.h,0,view),point(s,0,s.h,0,view)]}
function center(s,view){return point(s,s.w/2,s.h/2,0,view)}
function centerDepth(s,view){return geometry(s,0,view).c[2]}
function bounds(s,view){var xs=[],ys=[];for(var l=0;l<layerCount(s);l++){var m=matrix(s,l,view);for(var c=0;c<4;c++){var x=c===1||c===2?s.w:0,y=c>=2?s.h:0;xs.push(m[0]*x+m[1]*y+m[3]);ys.push(m[4]*x+m[5]*y+m[7])}}return {left:Math.min.apply(null,xs),right:Math.max.apply(null,xs),top:Math.min.apply(null,ys),bottom:Math.max.apply(null,ys)}}
function move(s,dx,dy,view){
 var n=copy(s),p=center(s,view),tx=p[0]+dx,ty=p[1]+dy,oldRadius=Math.sqrt(Math.pow(p[0]-camera.x,2)+Math.pow(p[1]-camera.y,2)),newRadius=Math.sqrt(Math.pow(tx-camera.x,2)+Math.pow(ty-camera.y,2));n.z=clamp(s.z-(newRadius-oldRadius)*.4,-120,420);
 var g=rotation(view?view.pitch:0,view?view.yaw:0,0),q=center(n,view),ex=tx-q[0],ey=ty-q[1],det=g[0]*g[4]-g[1]*g[3];if(Math.abs(det)>.0001){n.cx+=(ex*g[4]-ey*g[1])/det;n.cy+=(ey*g[0]-ex*g[3])/det}return n;
}

// Compute one conservative safe camera rectangle after layout changes, never per pointer event.
function cameraRange(items){
 var yaw=8,pitch=5;
 for(var pass=0;pass<10;pass++){
  var valid=true;
  for(var x=-2;x<=2&&valid;x++)for(var y=-2;y<=2;y++)if(!clear(items,{yaw:x*yaw/2,pitch:y*pitch/2})){valid=false;break}
  if(valid)return {yaw:yaw,pitch:pitch};yaw*=.8;pitch*=.8;
 }return {yaw:0,pitch:0};
}
function directView(candidate,range){return {yaw:clamp(candidate.yaw,-range.yaw,range.yaw),pitch:clamp(candidate.pitch,-range.pitch,range.pitch)}}
// One projection bundle per plate/frame; edges read cached endpoints, not repeated trig.
function renderBundle(s,view){
 var front=matrix(s,0,view),last=matrix(s,layerCount(s)-1,view),rails=[];
 var dx=last[3]-front[3],dy=last[7]-front[7],length=Math.sqrt(dx*dx+dy*dy),angle=Math.atan2(dy,dx)*180/Math.PI;
 for(var k=0;k<4;k++){var x=k===1||k===2?s.w:0,y=k>=2?s.h:0;rails.push({x:front[0]*x+front[1]*y+front[3],y:front[4]*x+front[5]*y+front[7],length:length,angle:angle})}
 var matrices=[];for(var n=0;n<layerCount(s);n++){var m=front.slice(0),t=n/Math.max(1,layerCount(s)-1);m[3]+=dx*t;m[7]+=dy*t;matrices.push(m)}
 return {matrices:matrices,rails:rails,depth:centerDepth(s,view)};
}
