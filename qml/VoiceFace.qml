import QtQuick 2.9
import Qing.Snow 1.0
import 'FaceLogic.js' as F
Rectangle {
 id:v;objectName:'voice-face';width:720;height:720;color:'#f2f1eb'
 property int skin:13
 property var owner:null
 property var store:null
 readonly property date clock:owner?owner.clock:new Date()
 readonly property bool ready:digits.status===FontLoader.Ready
 readonly property var sensorKeys:['airPM25','airCO2','airTEMP']
 readonly property string statusLabel:voice.status==='starting'?'准备聆听':voice.status==='listening'?'聆听中':voice.status==='transcribing'?'整理最后一句':voice.status==='done'?'已停止':voice.status==='error'?(voice.error==='tail_timeout'?'最后一句未完成':voice.error==='audio_backpressure'?'转写跟不上，已停止':voice.displayText!==''?'转写中断，文字已保留':'暂时无法聆听'):'未在聆听'
 FontLoader{id:digits;source:'file:///usr/share/fonts/DIN_Condensed_QP.ttf'}
 VoiceState{id:voice;store:v.store;active:v.visible&&v.owner!==null&&(v.owner.displayActive!==undefined?v.owner.displayActive:v.owner.visible)&&v.owner.panel===''&&!v.owner.isSaver}
 FaceText{x:44;y:35;width:300;height:43;text:Qt.formatDate(v.clock,'MM.dd')+' '+['周日','周一','周二','周三','周四','周五','周六'][v.clock.getDay()];font.pixelSize:23;color:'#667267'}
 FaceText{objectName:'seconds-display';property string secondsRole:'digital';x:352;y:24;width:324;height:73;text:Qt.formatTime(v.clock,'HH:mm:ss');font.family:digits.name;font.pixelSize:65;color:'#29372f';horizontalAlignment:Text.AlignRight}
 FaceText{x:44;y:103;width:550;height:52;text:'声笺';font.pixelSize:36;font.weight:Font.Medium;color:'#29372f'}
 Rectangle{x:48;y:177;width:8;height:8;radius:4;color:voice.status==='listening'?'#62836b':'#a4ada2'}
 FaceText{x:70;y:158;width:380;height:45;text:v.statusLabel;font.pixelSize:23;color:'#657569'}
 FaceText{x:478;y:159;width:198;height:44;text:voice.requested?'最多 20 秒':'';font.pixelSize:21;color:'#82917f';horizontalAlignment:Text.AlignRight}
 Rectangle{x:42;y:218;width:636;height:270;radius:22;color:'#fffef9';border.width:1;border.color:'#dce2d7'}
 Flickable{
  id:transcript;x:66;y:238;width:588;height:230;clip:true;contentWidth:width;contentHeight:words.height;boundsBehavior:Flickable.StopAtBounds
  FaceText{id:words;width:transcript.width;height:Math.max(transcript.height,paintedHeight);text:voice.displayText!==''?voice.displayText:voice.status==='listening'?'正在聆听…':voice.status==='transcribing'?'正在识别…':'轻点开始，说一段话';textFormat:Text.PlainText;wrapMode:Text.Wrap;font.pixelSize:34;lineHeight:1.3;verticalAlignment:Text.AlignTop;color:voice.displayText!==''?'#2c3830':'#a1aba0';elide:Text.ElideNone
   onTextChanged:Qt.callLater(function(){transcript.contentY=Math.max(0,transcript.contentHeight-transcript.height)})
  }
 }
 Rectangle{x:662;y:238+transcript.contentY/Math.max(1,transcript.contentHeight)*230;width:3;height:Math.max(22,230*230/Math.max(230,transcript.contentHeight));radius:2;color:'#b2c1ae';visible:transcript.contentHeight>transcript.height}
 Rectangle{
  x:42;y:508;width:636;height:64;radius:18;color:listen.pressed?'#58735f':'#6d8573';opacity:listen.enabled?1:.48
  FaceText{anchors.fill:parent;text:voice.requested?'停止聆听':voice.busy?'整理最后一句':'开始聆听';font.pixelSize:26;font.weight:Font.Medium;horizontalAlignment:Text.AlignHCenter;color:'#f7fbf4'}
  MouseArea{id:listen;anchors.fill:parent;enabled:voice.active&&v.store&&v.store.uptime>0&&(voice.requested||!voice.busy);onClicked:voice.requested?voice.stop():voice.start()}
 }
 Repeater{model:v.sensorKeys
  Rectangle{
   x:42+index*216;y:590;width:204;height:56;radius:12;color:'#e6ebe1'
   readonly property var sensor:airdataController[modelData]
   FaceText{x:12;y:3;width:82;height:25;text:F.label(modelData);font.pixelSize:18;color:'#647461'}
   FaceText{x:12;y:29;width:82;height:20;text:parent.sensor?parent.sensor.unitString:'';font.pixelSize:14;color:'#7e8d79'}
   FaceText{x:93;y:3;width:99;height:50;text:parent.sensor&&parent.sensor.state!==AirState.PreparingState?parent.sensor.valueString:'—';font.family:digits.name;font.pixelSize:43;fontSizeMode:Text.Fit;minimumPixelSize:28;color:'#344b39';horizontalAlignment:Text.AlignRight}
  }
 }
}
