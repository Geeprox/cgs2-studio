import QtQuick 2.9
import Qing.Snow 1.0
import 'FaceLogic.js' as F
Item{
 id:v
 property int skin:5
 property var owner
 property var store
 readonly property date clock:owner?owner.clock:new Date()
 readonly property string primaryKey:owner?owner.primaryKey:'airPM25'
 readonly property var primary:airdataController[primaryKey]
 readonly property var keys:F.secondary(primaryKey,0)
 readonly property bool paper:skin===9||skin===11
 readonly property color ink:paper?'#232a25':'#f2f0e4'
 readonly property color muted:paper?'#49564e':'#becbc1'
 Rectangle{anchors.fill:parent;color:skin===5?'#111e26':skin===7?'#161c1c':paper?'#e9dfcb':'#101c19'}
 Image{anchors.fill:parent;visible:skin===12;source:skin===12?'art/observatory.png':'';sourceSize.width:720;sourceSize.height:720}
 WeatherEffect{objectName:'weather-background';anchors.fill:parent;diagnostics:v.store&&v.store.weatherDiagnostics===true;onBenchmark:if(v.store)v.store.write("file:///tmp/cgs2-ui/metrics-weather-background.json",metrics);visible:v.skin===8&&F.supportsWeather(v.skin);sky:v.owner?v.owner.weatherSky:'';running:visible&&v.owner&&v.owner.visible&&v.owner.panel===''&&(!v.store||v.store.faceMotion!==false)}
 WeatherEffect{objectName:'weather-background';anchors.fill:parent;diagnostics:v.store&&v.store.weatherDiagnostics===true;onBenchmark:if(v.store)v.store.write("file:///tmp/cgs2-ui/metrics-weather-background.json",metrics);visible:F.supportsWeather(v.skin)&&v.store&&v.store.edgeWeather&&v.skin!==8;sky:v.owner?v.owner.weatherSky:'';ambient:true;artwork:v.skin>=9;running:visible&&v.owner&&v.owner.visible&&v.owner.panel===''&&(!v.store||v.store.faceMotion!==false)}
 Canvas{
  id:scene;anchors.fill:parent;visible:v.skin===5||v.skin===7
  onPaint:{var c=getContext('2d');c.clearRect(0,0,720,720);var h=v.clock.getHours()+v.clock.getMinutes()/60;
   c.save();c.translate(360,245);var scale=v.skin===5?.8:.72;c.scale(scale,scale);c.translate(-360,v.skin===5?-300:-310);
   if(v.skin===5){var cx=360,cy=300;c.lineWidth=1;c.strokeStyle='#435966';c.beginPath();c.arc(cx,cy,210,0,Math.PI*2);c.stroke();for(var i=0;i<96;i++){var a=(i/96*360-90)*Math.PI/180,r=i%4===0?194:201;c.strokeStyle=i%4===0?'#abbfc7':'#405966';c.lineWidth=i%4===0?2:1;c.beginPath();c.moveTo(cx+Math.cos(a)*r,cy+Math.sin(a)*r);c.lineTo(cx+Math.cos(a)*207,cy+Math.sin(a)*207);c.stroke()}for(var j=0;j<24;j+=6){var a=(j/24*360-90)*Math.PI/180;c.fillStyle='#c0cdd0';c.font='17px sans-serif';c.textAlign='center';c.fillText(String(j).padStart(2,'0'),cx+Math.cos(a)*180,cy+Math.sin(a)*180+6)}var a=(h/24*360-90)*Math.PI/180;c.fillStyle='#eecb85';c.beginPath();c.arc(cx+Math.cos(a)*210,cy+Math.sin(a)*210,9,0,Math.PI*2);c.fill();var g=c.createRadialGradient(360,300,10,360,300,160);g.addColorStop(0,'#668e9b');g.addColorStop(1,'#203842');c.fillStyle=g;c.beginPath();c.arc(360,300,160,0,Math.PI*2);c.fill()}
   else {var discs=[[306,270,178,'#737f75'],[408,305,166,'#c09c75'],[354,375,151,'#89756a']];for(var j=0;j<3;j++){var d=discs[j];c.globalAlpha=.83;c.fillStyle=d[3];c.beginPath();c.arc(d[0],d[1],d[2],0,Math.PI*2);c.fill()}c.globalAlpha=1;for(var n=0;n<12;n++){var a=(n*30-90)*Math.PI/180;c.fillStyle='#eae3d3';c.beginPath();c.arc(360+Math.cos(a)*143,310+Math.sin(a)*143,2,0,Math.PI*2);c.fill()}}
   if(v.skin===5||v.skin===7){var cx=360,cy=v.skin===5?300:310,angles=[(h%12)*30-90,(v.clock.getMinutes()+v.clock.getSeconds()/60)*6-90,v.clock.getSeconds()*6-90],lens=[78,117,135];for(var k=0;k<3;k++){var a=angles[k]*Math.PI/180;c.strokeStyle=k===2?'#e1ac6c':'#f4f0de';c.lineWidth=k===0?8:k===1?4:1.5;c.lineCap='round';c.beginPath();c.moveTo(cx-(k===2?18:0)*Math.cos(a),cy-(k===2?18:0)*Math.sin(a));c.lineTo(cx+lens[k]*Math.cos(a),cy+lens[k]*Math.sin(a));c.stroke()}c.fillStyle='#e1ac6c';c.beginPath();c.arc(cx,cy,4,0,Math.PI*2);c.fill()}
   c.restore();
  }
  Connections{target:v;function onClockChanged(){scene.requestPaint()}function onSkinChanged(){scene.requestPaint()}}
 }
 FaceText{x:110;y:44;width:500;height:36;text:Qt.formatDate(v.clock,'MM.dd')+'  '+['周日','周一','周二','周三','周四','周五','周六'][v.clock.getDay()];font.pixelSize:22;font.weight:Font.Medium;color:v.ink;horizontalAlignment:Text.AlignHCenter}
 FaceText{objectName:'seconds-display';property string secondsRole:v.skin===8||v.skin===12?'digital':'none';x:v.skin===10?82:70;y:v.skin===8?198:v.skin===10?100:90;width:v.skin===10?330:580;height:116;visible:v.skin!==5&&v.skin!==7;text:Qt.formatTime(v.clock,F.timeFormat(v.skin));font.family:'Roboto';font.weight:Font.Light;font.pixelSize:v.skin===8?94:88;font.letterSpacing:-4;color:v.ink;horizontalAlignment:v.skin===10?Text.AlignLeft:Text.AlignHCenter}
 FaceText{x:120;y:370;width:480;height:40;visible:v.skin===8;text:locationController.weatherData.isValid?locationController.cityName+'  '+locationController.weatherData.temperature+'°':'天气暂不可用';font.pixelSize:24;color:'#edf3e8';horizontalAlignment:Text.AlignHCenter}
 Rectangle{x:68;y:v.paper?402:478;width:584;height:v.paper?250:174;radius:25;color:v.paper?'#f0e8d8':'#101d1a';opacity:v.skin===8?.7:.93}
 Item{
  x:v.skin===10?82:88;y:v.skin===10?232:v.skin===5||v.skin===7?424:418;width:v.skin===10?280:544;height:v.skin===10?150:60
  FaceText{x:0;y:0;width:115;height:32;text:F.label(v.primaryKey);font.pixelSize:22;color:v.muted}
  FaceText{x:v.skin===10?0:123;y:v.skin===10?33:-7;width:v.skin===10?230:150;height:v.skin===10?105:67;text:v.primary&&v.primary.state!==AirState.PreparingState?v.primary.valueString:'—';font.family:v.owner?v.owner.numberFont:'Roboto';font.pixelSize:v.skin===10?100:62;color:v.ink;fontSizeMode:Text.Fit;minimumPixelSize:38}
  FaceText{x:v.skin===10?0:270;y:v.skin===10?128:25;width:120;height:26;text:v.primary?v.primary.unitString:'';font.pixelSize:17;color:v.muted}
  FaceText{x:390;y:4;width:154;height:30;visible:v.skin!==10;text:v.primary?v.primary.evalutionDescription:'';color:v.ink;font.pixelSize:21;horizontalAlignment:Text.AlignRight}
  MouseArea{anchors.fill:parent;onClicked:v.owner.history()}
 }
 Repeater{model:v.keys
  Item{
   x:88+index%3*190;y:496+Math.floor(index/3)*76;width:164;height:70
   readonly property var s:airdataController[modelData]
   FaceText{x:0;y:0;width:160;height:24;text:F.label(modelData);color:v.muted;font.pixelSize:17}
   FaceText{x:0;y:27;width:94;height:39;text:parent.s&&parent.s.state!==AirState.PreparingState?parent.s.valueString:'—';color:v.ink;font.family:v.owner?v.owner.numberFont:'Roboto';font.pixelSize:34;fontSizeMode:Text.Fit;minimumPixelSize:26}
   FaceText{x:96;y:38;width:68;height:24;text:parent.s?parent.s.unitString:'';color:v.muted;font.pixelSize:14}
   Rectangle{x:0;y:70;width:160;height:1;color:v.muted;opacity:.2;visible:index<3}
   MouseArea{anchors.fill:parent;onClicked:global.currentSensorNameOfDataPage=modelData}
  }
 }
 Canvas{
  id:bars;anchors.fill:parent;visible:v.skin===8
  onPaint:{var c=getContext('2d');c.clearRect(0,0,720,720);for(var i=0;i<6;i++){var key=v.keys[i],s=airdataController[key],left=i<3,x=left?32:688,y=145+i%3*132;c.strokeStyle='#d3e4e2';c.globalAlpha=.2;c.lineCap='round';c.lineWidth=5;c.beginPath();c.moveTo(x,y);c.lineTo(x,y+90);c.stroke();c.globalAlpha=1;c.strokeStyle=F.tint(key);c.beginPath();c.moveTo(x,y+90);c.lineTo(x,y+90-90*F.ratio(key,s));c.stroke()}}
  Timer{interval:10000;running:bars.visible;repeat:true;onTriggered:bars.requestPaint()}
  Connections{target:v;function onPrimaryKeyChanged(){bars.requestPaint()}}
 }
}
