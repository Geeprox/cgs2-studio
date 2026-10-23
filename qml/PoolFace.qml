import QtQuick 2.9
import 'FaceLayout.js' as Layout
Item{
 id:v;property var host
 readonly property var floats:[[72,221,-7],[505,238,6],[56,395,5],[518,406,-6],[186,510,-4],[425,521,7]]
 readonly property var colors:['#e1b57c','#e6b272','#e9b599','#a2c7af','#e7cf7e','#b4d9df','#c4d49e']
 property var defaults:({})
 property var positions:({})
 property string draggedKey:''
 property string anchoredKey:''
 readonly property var saved:host&&host.store&&host.store.faceLayouts?host.store.faceLayouts['7']:null
 onSavedChanged:load()
 onHostChanged:initialize()
 function initialize(){
  if(!host||Object.keys(defaults).length)return;
  var a={},keys=[host.primaryKey].concat(host.keys);a[keys[0]]={cx:360,cy:406};
  for(var i=1;i<keys.length;i++)a[keys[i]]={cx:floats[i-1][0]+70,cy:floats[i-1][1]+70};
  defaults=a;load()
 }
 function load(){if(!Object.keys(defaults).length)return;var p=JSON.parse(JSON.stringify(defaults));if(saved&&saved.items)for(var k in saved.items)p[k]=saved.items[k];positions=p}
 function save(){if(host&&host.store&&host.store.saveFaceLayout)host.store.saveFaceLayout(7,{items:positions})}
 function settle(k,x,y){return Layout.settlePool(k,x,y,positions,host?host.primaryKey:"")}
 function position(k){return positions[k]||{cx:360,cy:406}}
 function promote(k){if(!host)return;anchoredKey=k;host.choose(k);var p=JSON.parse(JSON.stringify(positions));p[k]=Layout.poolPosition(p[k].cx,p[k].cy,true);positions=p}
 function recordInteraction(kind,k){if(host&&host.store&&host.store.write)host.store.write('file:///tmp/cgs2-ui/last-face-interaction.json',{version:1,face:7,event:kind,key:k,primary:host.primaryKey,position:position(k),items:positions,at:Date.now()})}
 function interactionState(){return {skin:7,primary:host?host.primaryKey:"",items:positions,draggedKey:draggedKey}}
 function finish(k,x,y){
  anchoredKey=k;
  var p=JSON.parse(JSON.stringify(positions));p=Layout.dropPool(k,x,y,p,host?host.primaryKey:"");positions=p;draggedKey='';
  save();recordInteraction('drag',k);
 }
 readonly property int waterPaints:surface.paintedFrames
 readonly property bool materialsReady:surface.materialsReady||host&&host.foregroundOnly
 readonly property real wave:surface.phase*Math.PI/6
 PoolSurface{id:surface;anchors.fill:parent;visible:!v.host||!v.host.foregroundOnly;running:v.visible&&v.host&&v.host.animate;fixedTime:v.host?v.host.previewTime:0}
 ArtText{x:63;y:58;width:380;height:36;text:host?host.dateLabel():'';font.pixelSize:23;color:'#f7fff6';style:Text.Raised;styleColor:'#3a8ba0'}
 ArtText{x:196;y:85;width:461;height:125;text:host?Qt.formatTime(host.clock,'HH:mm'):'';font.family:host?host.tech:'';font.pixelSize:135;color:'#fffcec';horizontalAlignment:Text.AlignRight;style:Text.Raised;styleColor:'#3a8ba0'}
 Repeater{model:Layout.keys
  PoolFloat{
   objectName:'pool-'+modelData;layoutOwner:v;host:v.host;sensorKey:modelData;primary:v.host&&v.host.primaryKey===modelData
   centerX:v.position(modelData).cx;centerY:v.position(modelData).cy;tint:v.colors[index];wave:v.wave+index*.68;baseRotation:index===0?0:v.floats[index-1][2]
   onChosen:{if(primary&&v.host)v.host.history();else {v.promote(sensorKey);var p=JSON.parse(JSON.stringify(v.positions)),q=v.position(sensorKey);p=Layout.dropPool(sensorKey,q.cx,q.cy,p,v.host.primaryKey);v.positions=p;v.save()}v.recordInteraction('click',sensorKey)}
   onGrabbed:{v.anchoredKey=sensorKey;v.draggedKey=sensorKey}
   onDropped:v.finish(sensorKey,x,y)
  }
 }
 Component.onCompleted:initialize()
}
