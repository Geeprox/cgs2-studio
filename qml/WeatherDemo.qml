import QtQuick 2.9
Rectangle {
 id:p;objectName:'weather-demo';width:720;height:720;color:'#12212a'
 property var store
 property var owner
 property color accent:'#ff863c'
 property int selection:0
 property date clock:new Date()
 readonly property var skies:['CLEAR_DAY','CLEAR_NIGHT','PARTLY_CLOUDY_DAY','PARTLY_CLOUDY_NIGHT','CLOUDY','RAIN','SNOW','WIND','FOG','LIGHT_HAZE','DUST','THUNDERSTORM']
 readonly property var labels:['晴天','晴夜','日间多云','夜间多云','阴天','雨','雪','风','雾','雾霾','沙尘','雷雨']
 readonly property string sky:skies[selection]
 readonly property bool motion:!store||store.faceMotion!==false
 signal closed()
 function report(event){if(store&&store.write){var value={version:1,mode:'demo',event:event,index:selection,sky:sky,at:Date.now()};if(owner){value.originalFace=owner.skin;value.primary=owner.primaryKey;value.realSky=owner.weatherSky;value.weatherOverride=store.weatherOverride||''}store.write('file:///tmp/cgs2-ui/last-weather-demo.json',value)}}
 onOwnerChanged:if(owner)report('opened')
 function choose(n){selection=(n+skies.length)%skies.length;report('selected')}
 onStoreChanged:if(store)report('opened')
 Timer{interval:1000;running:p.visible;repeat:true;onTriggered:p.clock=new Date()}
 WeatherEffect{anchors.fill:parent;sky:p.sky;running:p.visible&&p.motion}
 WeatherParticles{anchors.fill:parent;sky:p.sky;running:p.visible&&p.motion;surfaces:[];exclusions:[[20,16,680,72],[80,115,560,210],[36,366,648,252],[60,638,600,72]]}
 Rectangle{x:22;y:20;width:676;height:66;radius:20;color:'#0b161d';opacity:.64}
 Action{x:26;y:24;width:64;height:58;label:'‹';onClicked:{p.report('closed');p.closed()}}
 FaceText{x:118;y:30;width:484;height:48;text:'天气演示';font.pixelSize:30;font.weight:Font.Medium;horizontalAlignment:Text.AlignHCenter}
 FaceText{x:120;y:118;width:480;height:35;text:Qt.formatDate(p.clock,'MM.dd')+' '+['周日','周一','周二','周三','周四','周五','周六'][p.clock.getDay()];font.pixelSize:24;horizontalAlignment:Text.AlignHCenter}
 FaceText{x:70;y:160;width:580;height:114;text:Qt.formatTime(p.clock,'HH:mm:ss');font.family:'DIN Condensed QP';font.pixelSize:102;horizontalAlignment:Text.AlignHCenter}
 FaceText{objectName:'demo-sky';x:100;y:284;width:520;height:46;text:'演示 · '+p.labels[p.selection];font.pixelSize:30;font.weight:Font.Medium;horizontalAlignment:Text.AlignHCenter}
 Repeater{model:p.labels
  Rectangle{
   x:42+index%3*216;y:370+Math.floor(index/3)*62;width:204;height:52;radius:14;color:p.selection===index?'#d4e6df':'#14252d';opacity:hit.pressed?.75:.94;border.width:p.selection===index?2:1;border.color:p.selection===index?'#f2fff8':'#5d777e'
   FaceText{anchors.fill:parent;text:modelData;font.pixelSize:22;color:p.selection===index?'#153037':'#edf6ef';horizontalAlignment:Text.AlignHCenter}
   MouseArea{id:hit;anchors.fill:parent;onClicked:p.choose(index)}
  }
 }
 Action{x:72;y:644;width:180;height:56;label:'‹ 上一个';onClicked:p.choose(p.selection-1)}
 FaceText{x:280;y:652;width:160;height:42;text:(p.selection+1)+' / '+p.skies.length;font.pixelSize:23;horizontalAlignment:Text.AlignHCenter}
 Action{x:468;y:644;width:180;height:56;label:'下一个 ›';onClicked:p.choose(p.selection+1)}
}
