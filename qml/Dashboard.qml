import QtQuick 2.9
import Qing.Snow 1.0
import 'FaceLogic.js' as F
Rectangle {
 id:d;width:720;height:720;color:'#030403'
 property var store:null
 property bool isSaver:false
 readonly property bool displayActive:visible&&(!store||store.displayAwake)
 property string panel:''
 property bool spatialPreview:false
 readonly property string secondsMode:F.secondsMode(skin,spatialPreview)
 property date clock:new Date()
 readonly property int skin:store?store.skin:0
 readonly property bool red:false
 readonly property string weatherSky:store&&store.weatherOverride?store.weatherOverride:locationController.weatherData.isValid?locationController.weatherData.skycon:''
 readonly property bool creative:skin===5||skin===7||skin>=8
 readonly property bool dial:skin===1
 readonly property bool litBackground:store&&store.edgeWeather&&weatherSky!==''
 readonly property color accent:red?'#ff5e4e':'#ff863c'
 readonly property color foreground:red?'#ff5e4e':'#f2f3eb'
 readonly property string primaryKey:global.currentSensorNameOfDataPage
 readonly property var primary:airdataController[primaryKey]||airdataController.airPM25
 readonly property string secondaryKey:primaryKey==='airCO2'?'airPM25':'airCO2'
 readonly property var smallKeys:F.secondary(primaryKey,skin)
 readonly property string numberFont:digits.name
 readonly property var samples:store&&store.historyData?store.historyData:({})
 FontLoader{id:digits;source:'file:///usr/share/fonts/DIN_Condensed_QP.ttf'}
 signal openRequested(string url)
 function history(){var paths={airPM25:'PM25/PM25',airPM10:'PM10/PM10',airCO2:'CO2/CO2',airTEMP:'TEMP/TEMP',airHUMI:'HUMI/HUMI',airTVOC:'TVOC/TVOC',airNoise:'Noise/Noise'};openRequested('qrc:/History/'+paths[primaryKey]+'HistoryPage.qml')}
 Timer{interval:1000;running:d.displayActive;repeat:true;onTriggered:d.clock=new Date()}

 function syncPresence(){if(store){store.microActive=panel==='micro'&&displayActive;store.mediaActive=['media','video','music'].indexOf(panel)>=0&&displayActive;store.activePanel=panel}}
 onPanelChanged:syncPresence()
 onDisplayActiveChanged:syncPresence()
 Component.onDestruction:if(store){store.microActive=false;store.mediaActive=false;store.activePanel=''}
 Item{id:presentation;anchors.fill:parent;visible:d.displayActive
 WeatherEffect{id:atmosphere;objectName:'weather-background';anchors.fill:parent;diagnostics:d.store&&d.store.weatherDiagnostics===true;onBenchmark:if(d.store)d.store.write("file:///tmp/cgs2-ui/metrics-weather-background.json",metrics);visible:F.supportsWeather(d.skin)&&d.store&&d.store.edgeWeather&&!d.creative;sky:d.weatherSky;ambient:true;running:d.visible&&visible&&d.panel===''&&(!d.store||d.store.faceMotion!==false)}
 Item{id:classic;anchors.fill:parent;visible:!d.creative
 Image{anchors.fill:parent;objectName:'outer-scale';source:'rim.svg';visible:F.showsOuterScale(d.skin)}
 FaceText{
  objectName:'header-weekday';x:d.skin===1||d.skin===2?90:146;y:d.skin===1||d.skin===2?54:42;width:d.skin===1||d.skin===2?180:140;height:d.skin===1||d.skin===2?44:52
  text:d.skin===2?'星期'+['日','一','二','三','四','五','六'][d.clock.getDay()]:['周日','周一','周二','周三','周四','周五','周六'][d.clock.getDay()]+' '+Qt.formatDate(d.clock,'MM.dd')
  font.pixelSize:d.skin===1||d.skin===2?26:20;font.weight:d.skin===1||d.skin===2?Font.Medium:Font.Normal;color:d.litBackground?'#e0e4db':'#c0c7b9';wrapMode:Text.NoWrap
 }
 Item{
  objectName:'header-weather';x:d.skin===1||d.skin===2?450:475;y:d.skin===1||d.skin===2?54:43;width:d.skin===1||d.skin===2?180:132;height:d.skin===1||d.skin===2?44:40
  Image{x:0;y:d.skin===1||d.skin===2?6:3;width:d.skin===1||d.skin===2?32:26;height:width;source:locationController.weatherData.isValid?'qrc:/screensaver/weather/'+locationController.weatherData.skycon.toLowerCase()+'.png':'';visible:locationController.weatherData.isValid}
  FaceText{x:d.skin===1||d.skin===2?42:32;y:0;width:d.skin===1||d.skin===2?138:100;height:d.skin===1||d.skin===2?44:34;text:locationController.weatherData.isValid?locationController.weatherData.temperature+'°':'天气 —';font.pixelSize:d.skin===1||d.skin===2?26:20;font.weight:d.skin===1||d.skin===2?Font.Medium:Font.Normal;color:d.litBackground?'#e0e4db':'#c0c7b9'}
  MouseArea{anchors.fill:parent;onClicked:d.openRequested('qrc:/Forecast/Weather/WeatherPage.qml')}
 }
 Text{
  objectName:'seconds-display';property string secondsRole:d.skin===3?'digital':'none'
  x:skin===1?280:skin===4?424:96;y:skin===1?55:skin===3?79:skin===4?83:skin===7?82:242
  width:skin===1?160:skin===4?200:528;height:skin===1?94:skin===4?78:skin===7?88:132
  visible:skin!==2&&skin!==6
  text:Qt.formatTime(d.clock,F.timeFormat(d.skin));color:d.foreground;font.family:skin===1||skin===4?d.numberFont:'Roboto';font.weight:Font.Light;font.pixelSize:skin===1?82:skin===3?108:skin===4?66:skin===7?78:124;font.letterSpacing:skin===1||skin===4?-1:-6
  horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter
  MouseArea{anchors.fill:parent;onClicked:d.openRequested('qrc:/Modules/DateTime/DateTimePage.qml')}
 }
 FaceText{objectName:'header-center-date';x:270;y:49;width:180;height:54;visible:skin===2;text:Qt.formatDate(d.clock,'MM.dd');font.pixelSize:36;font.weight:Font.DemiBold;horizontalAlignment:Text.AlignHCenter}
 FaceDial{objectName:'seconds-display';property string secondsRole:analogue?'analogue':'none';x:skin===6?104:207;y:skin===2?174:skin===6?258:202;width:skin===6?224:306;height:width;visible:skin===1||skin===2||skin===6;analogue:skin!==1;clock:d.clock;sensorKey:d.primaryKey;sensor:d.primary}
 FaceReading{
  id:mainReading;x:skin===1?245:skin===2?296:skin===6?362:96;y:skin===1?255:skin===2?520:skin===3?222:skin===4?126:skin===6?258:skin===7?202:390
  width:skin===1?230:skin===2?128:skin===6?262:528;height:skin===1?212:skin===2?128:skin===3?140:skin===4?292:skin===6?224:skin===7?116:100
  style:skin;night:d.red;litBackground:d.litBackground;sensor:d.primary;sensorKey:d.primaryKey;numberFont:d.numberFont;samples:d.samples[d.primaryKey]||[]
  onClicked:d.history()
 }
 FaceReading{x:96;y:382;width:528;height:140;style:3;litBackground:d.litBackground;visible:d.skin===3;sensor:airdataController[d.secondaryKey];sensorKey:d.secondaryKey;numberFont:d.numberFont;samples:d.samples[d.secondaryKey]||[];onClicked:global.currentSensorNameOfDataPage=d.secondaryKey}
 Repeater{model:d.smallKeys
  FaceComp{x:F.pos(d.skin,index)[0];y:F.pos(d.skin,index)[1];sensor:airdataController[modelData];sensorKey:modelData;style:d.skin;night:d.red;litBackground:d.litBackground;numberFont:d.numberFont;onClicked:global.currentSensorNameOfDataPage=modelData}
 }
 }
 Loader{id:creativeLoader;objectName:'creativeLoader';anchors.fill:parent;active:d.creative;source:active?(d.skin===13?'VoiceFace.qml':F.usesArtFace(d.skin,d.spatialPreview)?'ArtFace.qml':'CreativeFace.qml'):'';onLoaded:{item.skin=Qt.binding(function(){return d.skin});item.owner=d;item.store=Qt.binding(function(){return d.store})}}
 WeatherParticles{objectName:'weather-particles';anchors.fill:parent;sky:d.weatherSky;surfaces:F.weatherSurfaces(d.skin);exclusions:F.weatherExclusions(d.skin);visible:F.supportsWeather(d.skin)&&(d.skin===8||d.store&&d.store.edgeWeather)&&(kind!=='');running:d.visible&&visible&&d.panel===''&&(!d.store||d.store.faceMotion!==false);diagnostics:d.store&&d.store.weatherDiagnostics===true;onBenchmark:if(d.store)d.store.write("file:///tmp/cgs2-ui/metrics-weather-particles.json",metrics)}
 FaceText{x:240;y:12;width:240;height:28;visible:d.store&&d.store.weatherOverride!==undefined&&d.store.weatherOverride!=='';text:'天气演示 · '+atmosphere.sceneLabel;font.pixelSize:17;color:'#d4d3ba';horizontalAlignment:Text.AlignHCenter}
 SecondsRim{objectName:'seconds-display';property string secondsRole:'rim';anchors.fill:parent;clock:d.clock;visible:d.secondsMode==='rim';subtle:d.skin>=9;ink:d.skin===9||d.skin===11?'#8c421e':'#ff9b45'}
 Rectangle{
  objectName:'main-menu-entry';x:276;y:650;width:168;height:52;radius:26
  color:d.skin===9||d.skin===11||d.skin===13?'#dce5d6':'#183026';opacity:menuHit.pressed?.74:.95
  FaceText{anchors.fill:parent;text:'主菜单';font.pixelSize:23;color:F.navigationInk(d.skin);horizontalAlignment:Text.AlignHCenter}
  MouseArea{id:menuHit;anchors.fill:parent;preventStealing:true;onClicked:d.panel='menu'}
 }
 Rectangle{visible:d.panel==='menu';anchors.fill:parent;color:'#10170e';z:10
  FaceText{x:60;y:48;width:600;height:50;text:'青萍';font.pixelSize:32}
  Repeater{model:['切换表盘','Codex Micro','相册','视频播放','音乐播放','恢复布局','显示与连接','天气演示','返回表盘']
   MenuCard{x:60+index%3*206;y:122+Math.floor(index/3)*170;width:188;height:152;kind:index;label:modelData;status:'';onClicked:{if(index===0)d.panel='skins';if(index===1)d.panel='micro';if(index===2)d.panel='media';if(index===3)d.panel='video';if(index===4)d.panel='music';if(index===5&&d.store.resetFaceLayout)d.store.resetFaceLayout(d.skin);if(index===6)d.panel='night-screen';if(index===7)d.panel='weather-demo';if(index===8)d.panel=''}}
  }
 }
 Loader{id:overlay;anchors.fill:parent;z:11;active:d.panel!==''&&d.panel!=='menu';source:d.panel==='skins'?'SkinPicker.qml':d.panel==='micro'?'MicroPanel.qml':['media','video','music'].indexOf(d.panel)>=0?'MediaPanel.qml':d.panel==='weather-demo'?'WeatherDemo.qml':d.panel==='night-screen'?'NightScreenPanel.qml':'ConnectionPanel.qml';onLoaded:{if(item.objectName==='media-panel')item.mediaKind=d.panel==='video'?'video':d.panel==='music'?'audio':'photo';item.store=d.store;item.accent=d.accent;if(item.objectName==='weather-demo')item.owner=d}
  Connections{target:overlay.item;ignoreUnknownSignals:true;function onClosed(){d.panel=''}function onConnectionRequested(){d.panel='connection'}function onOpenRequested(url){d.openRequested(url)}}
 }
 }
}
