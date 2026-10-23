import QtQuick 2.9
import 'FaceLayout.js' as Layout
import 'PoolWater.js' as Water
Item{
 id:f;width:200;height:200
 property real centerX:360
 property real centerY:406
 property real moveX:0
 property real moveY:0
 property real dragTilt:0
 property bool dragging:false
 x:centerX-100+moveX;y:centerY-100+moveY
 z:dragging?100:primary?20:1
 scale:(primary?.97:.7)*(dragging?1.045:1)
 Behavior on scale{enabled:f.visible;NumberAnimation{duration:200;easing.type:Easing.OutCubic}}
 signal grabbed()
 signal dropped(real x,real y)
 function cancelDrag(){dragging=false;moveX=0;moveY=0;dragTilt=0;if(layoutOwner&&layoutOwner.draggedKey===sensorKey)layoutOwner.draggedKey=""}
 onVisibleChanged:if(!visible){cancelDrag();releaseMotion.stop()}
 Behavior on centerX{enabled:f.visible&&!f.dragging&&(!f.layoutOwner||f.layoutOwner.anchoredKey!==f.sensorKey);SpringAnimation{spring:3;damping:.35;epsilon:.3}}
 Behavior on centerY{enabled:f.visible&&!f.dragging&&(!f.layoutOwner||f.layoutOwner.anchoredKey!==f.sensorKey);SpringAnimation{spring:3;damping:.35;epsilon:.3}}
 property var layoutOwner:null
 property var host
 property string sensorKey:''
 property color tint:'#e7aa70'
 property bool primary:false
 property real wave:0
 readonly property var buoy:Water.buoy(wave)
 property real heldX:0
 property real heldY:0
 property real heldRoll:0
 property real releaseBlend:1
 readonly property bool held:touch.pressed||dragging
 readonly property real bobX:held?heldX:heldX*(1-releaseBlend)+buoy.x*releaseBlend
 readonly property real bobY:held?heldY:heldY*(1-releaseBlend)+buoy.y*releaseBlend
 readonly property real bobRoll:held?heldRoll:heldRoll*(1-releaseBlend)+buoy.roll*releaseBlend
 function releaseFloat(){if(visible&&host&&host.animate){releaseMotion.restart()}else releaseBlend=1}
 onDraggingChanged:if(!dragging&&!touch.pressed)releaseFloat()
 NumberAnimation{id:releaseMotion;target:f;property:'releaseBlend';from:0;to:1;duration:550;easing.type:Easing.InOutSine}
 property real baseRotation:0
 readonly property real unit:width/200
 signal chosen()
 transform:Translate{x:f.bobX;y:f.bobY}
 rotation:baseRotation+bobRoll+dragTilt
 // A low contrast broad floor shadow is separate from the small water contact shadow.
 Canvas{
  x:-34*f.unit;y:3*f.unit;width:244*f.unit;height:244*f.unit
  onPaint:{var c=getContext('2d');c.clearRect(0,0,width,height);c.scale(f.unit,f.unit);var g=c.createRadialGradient(113,134,45,113,134,109);g.addColorStop(0,'rgba(0,77,109,.29)');g.addColorStop(.64,'rgba(0,77,109,.21)');g.addColorStop(1,'rgba(0,77,109,0)');c.fillStyle=g;c.fillRect(0,0,244,244)}
 }
 onPrimaryChanged:if(ring)ring.requestPaint()
 Canvas{
  id:ring;anchors.fill:parent
  onPaint:{var c=getContext('2d');c.clearRect(0,0,width,height);c.scale(f.unit,f.unit);
   c.fillStyle='rgba(0,86,110,.28)';c.beginPath();c.arc(98,106,96,0,Math.PI*2);c.fill();
   var g=c.createRadialGradient(134,54,3,99,98,112);g.addColorStop(0,'#fff9e9');g.addColorStop(.53,f.tint);g.addColorStop(.84,f.tint);g.addColorStop(1,'#879f9c');c.fillStyle=g;c.beginPath();c.arc(100,100,95,0,Math.PI*2);c.fill();
   c.strokeStyle='rgba(255,255,255,.64)';c.lineWidth=2;c.beginPath();c.arc(100,100,92,Math.PI*1.12,Math.PI*1.94);c.stroke();
   if(f.primary){c.strokeStyle='#f4bd91';c.lineWidth=17;for(var i=0;i<4;i++){c.beginPath();c.arc(100,100,85,i*Math.PI/2-.22,i*Math.PI/2+.22);c.stroke()}}
   var inner=c.createLinearGradient(55,45,128,159);inner.addColorStop(0,'#fff9e9');inner.addColorStop(.65,'#f2efd8');inner.addColorStop(1,'#d9dec8');c.fillStyle=inner;c.beginPath();c.arc(100,100,77,0,Math.PI*2);c.fill();
   c.strokeStyle='rgba(96,119,115,.23)';c.lineWidth=1;c.beginPath();c.arc(100,100,77,0,Math.PI*2);c.stroke();
  }
 }
 ArtText{x:f.width*.12;y:f.height*.22;width:f.width*.76;height:f.height*.16;text:f.host?f.host.label(f.sensorKey):'';font.pixelSize:f.primary?25:28;color:'#326372';horizontalAlignment:Text.AlignHCenter}
 ArtText{x:f.width*.11;y:f.height*.40;width:f.width*.78;height:f.height*.28;text:f.host?f.host.value(f.sensorKey):'';font.family:f.host?f.host.tech:'';font.pixelSize:f.primary?76:62;fontSizeMode:Text.Fit;minimumPixelSize:28;color:'#174a5d';horizontalAlignment:Text.AlignHCenter}
 ArtText{x:f.width*.10;y:f.height*.70;width:f.width*.80;height:f.height*.14;text:f.host?f.host.unit(f.sensorKey):'';font.pixelSize:f.primary?19:23;color:'#477b86';horizontalAlignment:Text.AlignHCenter}
 MouseArea{
  id:touch;anchors.fill:parent;preventStealing:true
  property point start:Qt.point(0,0)
  property point last:Qt.point(0,0)
  property real stamp:0
  property real vx:0
  property real vy:0
  onPressed:{f.heldX=f.buoy.x;f.heldY=f.buoy.y;f.heldRoll=f.buoy.roll;releaseMotion.stop();f.cancelDrag();start=mapToItem(f.parent,mouse.x,mouse.y);last=start;stamp=Date.now();vx=0;vy=0}
  onPositionChanged:{
   if(!pressed)return;var p=mapToItem(f.parent,mouse.x,mouse.y),dx=p.x-start.x,dy=p.y-start.y;
   if(!f.dragging&&Layout.distance(dx,dy)<10)return;
   if(!f.dragging){f.dragging=true;f.grabbed()}
   var dt=Math.max(16,Math.min(80,Date.now()-stamp));vx=(p.x-last.x)/dt;vy=(p.y-last.y)/dt;last=p;stamp=Date.now();
   var bounded=Layout.poolPosition(f.centerX+dx,f.centerY+dy,f.primary);f.moveX=bounded.cx-f.centerX;f.moveY=bounded.cy-f.centerY;f.dragTilt=Layout.clamp(vx*3,-8,8)
  }
  onReleased:{if(!f.dragging){f.releaseFloat();f.chosen();return}var p=Layout.poolPosition(f.centerX+f.moveX,f.centerY+f.moveY,f.primary);f.dropped(p.cx,p.cy);f.moveX=0;f.moveY=0;f.dragTilt=0;f.dragging=false}
  onCanceled:{f.cancelDrag();f.releaseFloat()}
 }

}
