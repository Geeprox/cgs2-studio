import QtQuick 2.9
import 'MediaLogic.js' as Logic
Item {
 id:r;clip:true
 property url preloadSource
 property url source
 property bool fillScreen:true
 property bool motionEnabled:false
 property bool active:true
 property int intervalMs:10000
 property int slideSeed:0
 property int shown:-1
 property int pending:-1
 property bool failed:false
 property real transitionProgress:1
 property int transitionMode:0
 property int transitionCount:0
 readonly property bool transitionRunning:cross.running
 readonly property url displayedSource:shown<0?'':image(shown).source
 readonly property bool preloadReady:shown>=0&&String(preloadSource)!==''&&String(image(shown===0?1:0).source)===String(preloadSource)&&image(shown===0?1:0).status===Image.Ready
 readonly property real motionProgress:shown<0?0:image(shown).progress
 function image(i){return i===0?a:b}
 function animation(i){return i===0?za:zb}
 function syncMotion(){
  if(!a||!b||!za||!zb)return
  for(var i=0;i<2;i++){
   var z=animation(i),play=i===shown&&active&&motionEnabled&&fillScreen
   if(play){image(i).hasMotion=true;if(!z.running&&image(i).progress<1)z.start();z.paused=false}
   else if(z.running)z.paused=true
  }
 }
 function warm(){
  if(!active||cross.running||pending>=0||shown<0||String(preloadSource)===''||String(preloadSource)===String(displayedSource))return
  image(shown===0?1:0).source=preloadSource
 }
 function load(){
  if(!a||!b||!za||!zb)return
  failed=false
  if(String(source)===''){pending=-1;shown=-1;za.stop();zb.stop();cross.stop();a.source='';b.source='';return}
  if(shown>=0&&String(image(shown).source)===String(source))return
  var i=shown===0?1:0,next=image(i),z=animation(i)
  z.stop();next.progress=0;next.hasMotion=false
  z.duration=Math.max(3000,Math.min(60000,intervalMs));pending=i
  next.source=source
  if(next.status===Image.Ready)loaded(i)
 }
 function loaded(i){
  if(i!==pending||String(image(i).source)!==String(source))return
  var previous=shown,next=image(i)
  next.plan=Logic.motionPlan(next.implicitWidth,next.implicitHeight,width,height,Math.floor(Math.random()*2147483647),intervalMs,!motionEnabled)
  cross.stop();transitionMode=(transitionMode+1+Math.floor(Math.random()*2))%3;transitionProgress=previous<0?1:0
  shown=i;pending=-1;failed=false;syncMotion()
  if(previous>=0){transitionCount++;cross.restart();}else warmTimer.restart()
 }
 onPreloadSourceChanged:warmTimer.restart()
 onSourceChanged:load()
 onMotionEnabledChanged:syncMotion()
 onActiveChanged:{syncMotion();if(active)warmTimer.restart();else {cross.stop();transitionProgress=1}}
 onFillScreenChanged:syncMotion()
 Component.onCompleted:load()
 NumberAnimation{id:cross;target:r;property:'transitionProgress';from:0;to:1;duration:r.transitionMode===0?650:r.transitionMode===1?580:760;easing.type:Easing.InOutSine;onStopped:if(r.transitionProgress>=.999)r.warm()}
 Image{
  id:a;anchors.centerIn:parent
  property real progress:0
  property bool hasMotion:false
  property var plan:({z0:1,z1:1.2,x0:0,x1:0,y0:0,y1:0})
  readonly property real aspect:implicitWidth/Math.max(1,implicitHeight)
  readonly property bool front:r.shown===0
  width:r.fillScreen?Math.max(r.width,r.height*aspect):r.width
  height:r.fillScreen?Math.max(r.height,r.width/Math.max(.01,aspect)):r.height
  opacity:r.shown<0?0:front?r.transitionProgress:r.transitionRunning?1:0
  z:front?1:0
  fillMode:Image.PreserveAspectFit
  asynchronous:true;cache:false;smooth:true;autoTransform:true;sourceSize.width:1280;sourceSize.height:1280
  scale:(r.fillScreen&&hasMotion?plan.z0+(plan.z1-plan.z0)*progress:1)*(front&&r.transitionMode===2?1+.055*(1-r.transitionProgress):1)
  transform:Translate{x:(r.fillScreen&&a.hasMotion?a.plan.x0+(a.plan.x1-a.plan.x0)*a.progress:0)+(a.front&&r.transitionMode===1?26*(1-r.transitionProgress):0);y:r.fillScreen&&a.hasMotion?a.plan.y0+(a.plan.y1-a.plan.y0)*a.progress:0}
  onStatusChanged:{if(status===Image.Ready)r.loaded(0);else if(status===Image.Error&&r.pending===0)r.failed=true}
 }
 Image{
  id:b;anchors.centerIn:parent
  property real progress:0
  property bool hasMotion:false
  property var plan:({z0:1,z1:1.2,x0:0,x1:0,y0:0,y1:0})
  readonly property real aspect:implicitWidth/Math.max(1,implicitHeight)
  readonly property bool front:r.shown===1
  width:r.fillScreen?Math.max(r.width,r.height*aspect):r.width
  height:r.fillScreen?Math.max(r.height,r.width/Math.max(.01,aspect)):r.height
  opacity:r.shown<0?0:front?r.transitionProgress:r.transitionRunning?1:0
  z:front?1:0
  fillMode:Image.PreserveAspectFit
  asynchronous:true;cache:false;smooth:true;autoTransform:true;sourceSize.width:1280;sourceSize.height:1280
  scale:(r.fillScreen&&hasMotion?plan.z0+(plan.z1-plan.z0)*progress:1)*(front&&r.transitionMode===2?1+.055*(1-r.transitionProgress):1)
  transform:Translate{x:(r.fillScreen&&b.hasMotion?b.plan.x0+(b.plan.x1-b.plan.x0)*b.progress:0)+(b.front&&r.transitionMode===1?26*(1-r.transitionProgress):0);y:r.fillScreen&&b.hasMotion?b.plan.y0+(b.plan.y1-b.plan.y0)*b.progress:0}
  onStatusChanged:{if(status===Image.Ready)r.loaded(1);else if(status===Image.Error&&r.pending===1)r.failed=true}
 }
 Timer{id:warmTimer;interval:120;onTriggered:r.warm()}
 NumberAnimation{id:za;target:a;property:'progress';to:1;duration:10000;easing.type:Easing.InOutSine}
 NumberAnimation{id:zb;target:b;property:'progress';to:1;duration:10000;easing.type:Easing.InOutSine}
}
