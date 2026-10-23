import QtQuick 2.9
import 'FaceLayout.js' as Layout
import 'NightScreen.js' as Night
Item {
 id:s
 // Native screen state covers night schedules, idle auto-off and the power key.
 // Desktop fixtures can omit the hardware context; production exposes this bool.
 readonly property bool displayAwake:typeof screenManager==='undefined'?true:screenManager.isScreenOn
 readonly property var nightTimer:typeof datetimeManager==='undefined'?null:datetimeManager.nightTimer
 readonly property bool nightEnabled:nightTimer?nightTimer.enabled===true:false
 readonly property int nightStartMinutes:nightTimer?nightTimer.startMinutes:Night.defaultStart
 readonly property int nightEndMinutes:nightTimer?nightTimer.endMinutes:Night.defaultEnd
 property date nightClock:new Date()
 readonly property bool nightWindowActive:Night.inWindow(nightEnabled,nightStartMinutes,nightEndMinutes,nightClock.getHours()*60+nightClock.getMinutes())
 function setNightEnabled(enabled){return Night.setEnabled(nightTimer,enabled)}
 function saveNightSchedule(start,end){return Night.apply(nightTimer,start,end,nightEnabled)}
 property string activePanel:''
 readonly property bool nativeScreenAvailable:typeof screenManager!=='undefined'
 readonly property var nativeAutomaticBrightness:nativeScreenAvailable?screenManager.isAutoBrightness:null
 readonly property int nativeBrightnessValue:nativeScreenAvailable?screenManager.brightnessValue:-1
 property bool screenStateReady:false
 // Only the application's real input signal resets this clock. Media keep-awake
 // requests go directly to ScreenManager and cannot postpone backlight dimming.
 readonly property int idleDimTimeoutSeconds:60
 property int idleLastTouchUptime:-1
 property bool idleDimRequested:false
 function restoreIdleBrightness(){
  idleLastTouchUptime=uptime;idleDimRequested=false
  if(nativeScreenAvailable)screenManager.brightnessValue=-1000
  queueScreenState()
 }
 function updateIdleBrightness(){
  if(!displayAwake||uptime<=0)return
  if(idleLastTouchUptime<0||uptime<idleLastTouchUptime){idleLastTouchUptime=uptime;return}
  if(!idleDimRequested&&uptime-idleLastTouchUptime>=idleDimTimeoutSeconds){
   idleDimRequested=true
   if(nativeScreenAvailable)screenManager.brightnessValue=-1001
   queueScreenState()
  }
 }
 Connections{target:typeof global==='undefined'?null:global;ignoreUnknownSignals:true;function onInterfaceTouched(){s.restoreIdleBrightness()}}
 Timer{interval:1000;repeat:true;running:s.screenStateReady&&s.displayAwake;onTriggered:s.updateIdleBrightness()}
 property string screenStateLast:''
 property int screenStateLastUptime:-10
 function queueScreenState(){if(screenStateReady)screenStatePump.restart()}
 function writeScreenState(){
  if(!screenStateReady||uptime<=0)return
  if(displayAwake&&parent&&!parent.visible)return
  // Coalesce rapid native brightness ramps into at most one tmpfs write/second.
  if(uptime===screenStateLastUptime)return
  var panel=['','menu','skins','micro','media','video','music','display','screen','night','night-screen','connection','weather-demo'].indexOf(activePanel)>=0?activePanel:'other'
  var snapshot={version:1,nativeScreenAvailable:nativeScreenAvailable,nightTimerAvailable:nightTimer!==null,displayAwake:displayAwake,nightEnabled:nightEnabled,nightStartMinutes:nightStartMinutes,nightEndMinutes:nightEndMinutes,nightWindowActive:nightWindowActive,isAutoBrightness:nativeAutomaticBrightness,brightnessValue:nativeBrightnessValue,idleDimTimeoutSeconds:idleDimTimeoutSeconds,idleDimRequested:idleDimRequested,skin:skin,microActive:microActive,mediaActive:mediaActive,activePanel:panel}
  var fingerprint=JSON.stringify(snapshot)
  if(fingerprint===screenStateLast&&uptime>=screenStateLastUptime&&uptime-screenStateLastUptime<10)return
  screenStateLast=fingerprint;screenStateLastUptime=uptime;snapshot.uptime=uptime
  write('file:///tmp/cgs2-ui/screen-state.json',snapshot)
 }
 Timer{id:screenStatePump;interval:40;onTriggered:s.writeScreenState()}
 onDisplayAwakeChanged:{if(displayAwake&&screenStateReady)restoreIdleBrightness();queueScreenState()}
 onNightEnabledChanged:queueScreenState()
 onNightStartMinutesChanged:queueScreenState()
 onNightEndMinutesChanged:queueScreenState()
 onNightWindowActiveChanged:queueScreenState()
 onNativeAutomaticBrightnessChanged:queueScreenState()
 onNativeBrightnessValueChanged:queueScreenState()
 onSkinChanged:queueScreenState()
 onActivePanelChanged:queueScreenState()
 onMicroActiveChanged:queueScreenState()
 onMediaActiveChanged:queueScreenState()
 property int skin:1
 property bool edgeWeather:false
 property bool faceMotion:true
 property bool weatherDemoEnabled:false
 property bool weatherDiagnostics:false
 property string weatherDemoSky:''
 property int weatherDemoExpires:0
 readonly property string weatherOverride:weatherDemoEnabled&&uptime>0&&weatherDemoExpires>uptime&&weatherDemoExpires-uptime<600?weatherDemoSky:''
 function readWeatherDemo(){read('file:///tmp/cgs2-ui/weather-demo.json',function(v){
  s.weatherDemoEnabled=v.enabled===true
  s.weatherDiagnostics=v.metrics===true&&s.weatherDemoEnabled
  s.weatherDemoSky=['CLEAR_DAY','CLEAR_NIGHT','RAIN','SNOW','CLOUDY','WIND','DUST','FOG','LIGHT_HAZE'].indexOf(v.sky)>=0?v.sky:''
  s.weatherDemoExpires=Number.isInteger(v.expiresUptime)?v.expiresUptime:0
 })}
 property var historyData:({})
 property var faceLayouts:({})
 function saveFaceLayout(theme,value){
  var clean=Layout.clean(theme,value);if(!clean)return;
  var next=JSON.parse(JSON.stringify(faceLayouts));next[String(theme)]=clean;faceLayouts=next;
  write('file:///userdata/cgs2-ui/layouts.json',{version:1,themes:next})
 }
 function resetFaceLayout(theme){
  var next=JSON.parse(JSON.stringify(faceLayouts));delete next[String(theme)];faceLayouts=next;
  write('file:///userdata/cgs2-ui/layouts.json',{version:1,themes:next})
 }
 function savePreferences(){write("file:///userdata/cgs2-ui/preferences.json",{version:4,skin:skin,edgeWeather:edgeWeather,faceMotion:faceMotion})}
 function toggleFaceMotion(){faceMotion=!faceMotion;savePreferences()}
 function toggleWeather(){edgeWeather=!edgeWeather;savePreferences()}
 property var micro:({})
 property var recovery:({})
 property bool microActive:false
 property bool mediaActive:false
 property int microAge:99
 property int lastStamp:-1
 property int uptime:0
 property string pending:''
 property string feedback:''
 property int pendingTicks:0
 readonly property bool online:micro.connected===true&&micro.bridgeConnected===true&&microAge<7
 function readText(url,callback){var r=new XMLHttpRequest();r.open('GET',url);r.onreadystatechange=function(){if(r.readyState===XMLHttpRequest.DONE&&(r.status===0||r.status===200))callback(r.responseText)};r.send()}
 function read(url,callback){readText(url,function(t){try{callback(JSON.parse(t))}catch(e){}})}
 // Qt's local-file PUT overwrites without truncating. Use fixed-size ASCII JSON slots.
 property var activeWrites:({})
 property var queuedWrites:({})
 function sendText(url,text){
  queuedWrites[url]=text;writePump.restart()
 }
 function flushWrites(){for(var url in queuedWrites)if(!activeWrites[url]){var text=queuedWrites[url];delete queuedWrites[url];startWrite(url,text)}}
 Timer{id:writePump;interval:40;onTriggered:s.flushWrites()}
 function startWrite(url,text){
  var r=new XMLHttpRequest();activeWrites[url]=r;r.open('PUT',url)
  // Let the completed local-file request close before opening the next PUT.
  r.onreadystatechange=function(){if(r.readyState===XMLHttpRequest.DONE){delete activeWrites[url];if(queuedWrites[url]!==undefined)writePump.restart()}}
  r.send(text)
 }
 function write(url,value){
  var text=JSON.stringify(value).replace(/[\u007f-\uffff]/g,function(c){return '\\u'+('0000'+c.charCodeAt(0).toString(16)).slice(-4)})
  var size=url.indexOf('preferences.json')>=0?1024:4096
  if(text.length>size){console.warn('JSON_WRITE_TOO_LARGE');return false}
  sendText(url,text+new Array(size-text.length+1).join(' '));return true
 }
 function chooseSkin(n){if(!(n>=0&&n<14)&&n!==100)return;skin=n;savePreferences()}
 function command(type,extra){
  if(!online||!microActive||pending!==''||uptime<=0)return
  if(type!=='key'&&type!=='reasoning')return
  var action={type:type};if(extra)for(var k in extra)action[k]=extra[k]
  var id='ui_'+uptime+'_'+Math.floor(Math.random()*1000000000)
  pending=id;pendingTicks=0;feedback='正在执行…'
  write('file:///tmp/cgs2-micro-lan/presence.json',{uptime:uptime})
  write('file:///tmp/cgs2-micro-lan/request.json',{id:id,uptime:uptime,action:action})
 }
 function recover(){write('file:///tmp/cgs2-ui/recovery-request.json',{id:'recover-'+Date.now()})}
 function rebootForWifi(){write('file:///tmp/cgs2-ui/recovery-request.json',{id:'reboot-'+Date.now(),action:'reboot'})}
 function poll(){
  nightClock=new Date()
  if(weatherDemoEnabled)readWeatherDemo()
  readText('file:///proc/uptime',function(t){var n=parseInt(t);if(isFinite(n))s.uptime=n})
  microAge++
  read('file:///tmp/cgs2-micro-lan/status.json',function(v){
   micro=v;if(v.deviceUptime!==undefined&&v.deviceUptime!==lastStamp){lastStamp=v.deviceUptime;microAge=0}
   if(pending!==''&&v.lastAction&&v.lastAction.id===pending){feedback=v.lastAction.message||(v.lastAction.ok?'Mac 已确认':'未执行');pending=''}
  })
  read('file:///tmp/cgs2-ui/recovery-status.json',function(v){recovery=v})
  if(uptime%10===0)read('file:///tmp/cgs2-ui/history.json',function(v){historyData=v})
  if(mediaActive&&displayAwake&&uptime>0)write('file:///tmp/cgs2-media/presence.json',{uptime:uptime})
  if(microActive&&displayAwake&&uptime>0)write('file:///tmp/cgs2-micro-lan/presence.json',{uptime:uptime})
  if(pending!==''&&++pendingTicks>9){pending='';feedback='未收到执行确认；操作不会自动重试'}
  writeScreenState()
 }
 Timer{interval:1000;running:true;repeat:true;triggeredOnStart:true;onTriggered:s.poll()}
 Component.onCompleted:{
  screenStateReady=true;queueScreenState()
  read('file:///userdata/cgs2-ui/layouts.json',function(v){if(v.version!==1||!v.themes)return;var next={};for(var k in v.themes){var clean=Layout.clean(k,v.themes[k]);if(clean)next[k]=clean}s.faceLayouts=next})
  readWeatherDemo()
  read('file:///tmp/cgs2-ui/history.json',function(v){historyData=v})
  read('file:///userdata/cgs2-ui/preferences.json',function(v){
   if(Number.isInteger(v.skin))s.skin=v.version>=4?((v.skin>=0&&v.skin<14)||v.skin===100?v.skin:1):v.version===3?(v.skin===8?100:v.skin):v.skin===2?5:v.skin===3?100:v.skin
   s.edgeWeather=v.edgeWeather===true
   s.faceMotion=v.faceMotion!==false
  })
 }
}
