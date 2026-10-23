import QtQuick 2.9
import 'SpatialProjection.js' as Space
import 'FaceLayout.js' as Layout
Item{
 id:v;objectName:'space-face';property var host
 property bool initialized:false
 property string layoutPrimary:""
 readonly property string primaryKey:host?host.primaryKey:""
 onPrimaryKeyChanged:if(initialized&&primaryKey&&layoutPrimary!==primaryKey){positions=Space.select(positions,layoutPrimary,primaryKey);layoutPrimary=primaryKey;var safe=Space.restore(primaryKey,positions,view);positions=safe.items;view=safe.view}
 property var positions:({})
 property var view:({yaw:0,pitch:0})
 property var cameraRange:({yaw:0,pitch:0})
 property var wantedView:({yaw:0,pitch:0})
 property int cameraFrames:0
 property bool saving:false
 property var lastApplied:({yaw:0,pitch:0})
 function updateCameraRange(){cameraRange=Space.cameraRange(positions);view=Space.directView(view,cameraRange)}
 function applyCamera(){view=Space.directView(wantedView,cameraRange);lastApplied={yaw:view.yaw,pitch:view.pitch};cameraFrames++}
 Timer{id:cameraFrame;interval:16;repeat:false;onTriggered:v.applyCamera()}
 property var dragStart:null
 property string draggedKey:''
 readonly property int layoutTheme:host&&host.skin===5?5:12
 readonly property var saved:host&&host.store&&host.store.faceLayouts?host.store.faceLayouts[String(layoutTheme)]:null
 readonly property bool materialsReady:wide.status===FontLoader.Ready
 onSavedChanged:if(!saving)load()
 onHostChanged:initialize()
 function initialize(){if(!host||initialized)return;initialized=true;layoutPrimary=host.primaryKey;load()}
 function load(){if(!initialized)return;var safe=Space.restore(host.primaryKey,saved&&saved.items,saved&&saved.view);positions=safe.items;view=safe.view;layoutPrimary=host.primaryKey;updateCameraRange()}
 function spec(k){return positions[k]||Space.primary}
 function promote(k){if(!host)return;var safe=Space.restore(k,Space.select(positions,layoutPrimary,k),view);layoutPrimary=k;positions=safe.items;view=safe.view;updateCameraRange();host.choose(k)}
 function begin(k){draggedKey=k;dragStart=JSON.parse(JSON.stringify(spec(k)))}
 function move(k,dx,dy){if(!dragStart)return;var p=JSON.parse(JSON.stringify(positions));p[k]=Space.safeMove(positions,k,dragStart,dx,dy,view);positions=p}
 function interactionState(){return {skin:host?host.skin:12,layoutTheme:layoutTheme,primary:host?host.primaryKey:"",items:positions,view:view,draggedKey:draggedKey}}
 function save(){if(host&&host.store&&host.store.saveFaceLayout){var snapshot={items:positions,view:{yaw:view.yaw,pitch:view.pitch}};saving=true;host.store.saveFaceLayout(layoutTheme,snapshot);saving=false;positions=snapshot.items;view=snapshot.view}}

 function recordInteraction(event,k){if(host&&host.store&&host.store.write)host.store.write('file:///tmp/cgs2-ui/last-face-interaction.json',{version:1,face:host.skin,event:event,key:k||'',primary:host.primaryKey,items:positions,view:view,wantedView:wantedView,lastApplied:lastApplied,cameraFrames:cameraFrames,cameraRange:cameraRange,at:Date.now()})}
 function finish(){var k=draggedKey;draggedKey='';dragStart=null;updateCameraRange();save();recordInteraction('drag',k)}
 FontLoader{id:wide;source:'file:///usr/share/fonts/Roboto-Regular.ttf'}
 Rectangle{anchors.fill:parent;color:'#0d1010';z:-2000}
 // Frames interleave across opposing planes; all protected text stays above them.
 Item{id:depthLayer;anchors.fill:parent;z:-500}
 Item{id:readingLayer;anchors.fill:parent;z:10}
 MouseArea{anchors.fill:parent;z:-1900;preventStealing:true
  property point start:Qt.point(0,0);property var initial:({yaw:0,pitch:0});property bool moved:false
  onPressed:{start=Qt.point(mouse.x,mouse.y);initial={yaw:v.view.yaw,pitch:v.view.pitch};moved=false;v.wantedView=initial}
  onPositionChanged:{if(!pressed)return;var dx=mouse.x-start.x,dy=mouse.y-start.y;if(!moved&&Layout.distance(dx,dy)<10)return;moved=true;v.wantedView={yaw:initial.yaw-dx*.065,pitch:initial.pitch+dy*.05};if(!cameraFrame.running)cameraFrame.start()}
  onReleased:if(moved){cameraFrame.stop();v.applyCamera();v.save();v.recordInteraction('camera','')}
  onCanceled:cameraFrame.stop()
 }
 Repeater{model:Layout.keys
  PerspectiveMetric{objectName:'space-'+modelData;depthHost:depthLayer;readingHost:readingLayer;host:v.host;sensorKey:modelData;primary:v.host&&v.host.primaryKey===modelData;spec:v.spec(modelData);view:v.view;numberFont:wide.name;onChosen:{if(primary&&v.host)v.host.history();else {v.promote(sensorKey);v.save()}v.recordInteraction('click',sensorKey)}
   onGrabbed:v.begin(sensorKey);onMoved:v.move(sensorKey,dx,dy);onDropped:v.finish()}
 }
 PerspectiveMetric{depthHost:depthLayer;readingHost:readingLayer;objectName:'seconds-display';property string secondsRole:'digital';host:v.host;spec:Space.seconds;view:v.view;numberFont:wide.name;clockPlane:true;displayText:host?Qt.formatTime(host.clock,'ss'):''}
 PerspectiveMetric{depthHost:depthLayer;readingHost:readingLayer;host:v.host;spec:Space.clock;view:v.view;numberFont:wide.name;clockPlane:true;displayText:host?Qt.formatTime(host.clock,'HH:mm'):''}
 Rectangle{x:36;y:18;width:300;height:44;z:999;color:'#0d1010';opacity:.98}
 ArtText{x:45;y:24;width:290;height:30;z:1000;text:host?host.dateLabel():'';font.pixelSize:19;color:'#a7afaa'}
 Component.onCompleted:initialize()
}
