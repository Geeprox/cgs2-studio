import QtQuick 2.9
import 'NightScreen.js' as Night
Rectangle {
 id:p;objectName:'night-screen';width:720;height:720;color:'#10170e'
 property var store:null
 property color accent:'#ff863c'
 property int draftStart:Night.defaultStart
 property int draftEnd:Night.defaultEnd
 property string editing:''
 property string message:''
 readonly property bool available:!!(store&&store.nightTimer)
 readonly property bool enabledNight:!!(store&&store.nightEnabled===true)
 readonly property bool changed:!!(store&&(draftStart!==store.nightStartMinutes||draftEnd!==store.nightEndMinutes))
 readonly property bool valid:Night.validRange(draftStart,draftEnd)
 readonly property int editValue:editing==='start'?draftStart:draftEnd
 signal closed()
 signal connectionRequested()
 function loadDraft(){
  if(!store)return
  var range=Night.initialRange(store.nightStartMinutes,store.nightEndMinutes)
  draftStart=range[0];draftEnd=range[1];message=''
 }
 function shift(delta){
  if(editing==='start')draftStart=Night.shifted(draftStart,delta)
  else draftEnd=Night.shifted(draftEnd,delta)
  message=''
 }
 function save(){
  if(!valid){message='开始与结束时间需不同';return}
  message=store&&store.saveNightSchedule(draftStart,draftEnd)?'时段已保存':'暂时无法保存'
 }
 onStoreChanged:loadDraft()
 Component.onCompleted:loadDraft()

 Action{x:24;y:30;width:72;height:60;label:'‹';onClicked:p.closed()}
 FaceText{x:116;y:35;width:500;height:50;text:'显示与连接';font.pixelSize:32}
 Rectangle{x:48;y:114;width:624;height:100;radius:20;color:'#20281e'
  FaceText{x:24;y:16;width:340;height:36;text:'夜间息屏';font.pixelSize:28;font.weight:Font.Medium}
  FaceText{x:24;y:55;width:420;height:28;text:p.enabledNight?'每天按时关闭屏幕':'关闭 · 开启后适用于所有表盘';font.pixelSize:20;color:'#bdc7b6'}
  Rectangle{x:492;y:27;width:102;height:52;radius:26;color:p.enabledNight?'#a9c696':'#4a5345';opacity:p.available?1:.35
   Rectangle{x:p.enabledNight?56:6;y:6;width:40;height:40;radius:20;color:'#f2f3eb'}
   MouseArea{anchors.fill:parent;enabled:p.available;onClicked:{p.store.setNightEnabled(!p.enabledNight);p.message=''}}
  }
 }
 Repeater{model:2
  Rectangle{x:48+index*320;y:238;width:304;height:128;radius:20;color:'#20281e'
   FaceText{x:24;y:16;width:256;height:30;text:index===0?'开始息屏':'早晨恢复';font.pixelSize:22;color:'#bdc7b6'}
   FaceText{x:24;y:51;width:256;height:58;text:Night.formatMinute(index===0?p.draftStart:p.draftEnd);font.pixelSize:45;font.family:'DIN Condensed QP'}
   MouseArea{anchors.fill:parent;enabled:p.available;onClicked:p.editing=index===0?'start':'end'}
  }
 }
 FaceText{x:48;y:382;width:624;height:80;text:'闲置 1 分钟降低背光，触摸恢复。\n夜间闲置 1 分钟息屏，并暂停动效与媒体。';font.pixelSize:22;color:'#bdc7b6';wrapMode:Text.WordWrap;elide:Text.ElideNone;verticalAlignment:Text.AlignTop;maximumLineCount:2}
 Action{x:48;y:470;width:624;height:68;label:'保存时段';enabled:p.available&&p.changed&&p.valid;onClicked:p.save()}
 FaceText{x:48;y:546;width:624;height:36;text:!p.available?'设备暂未提供息屏设置':!p.valid?'开始与结束时间需不同':p.message!==''?p.message:p.changed?'时段尚未保存':p.enabledNight?(p.store.nightWindowActive?'当前处于夜间时段':'当前处于日间时段'):'可先设置时段，再开启夜间息屏';font.pixelSize:20;color:'#bdc7b6';horizontalAlignment:Text.AlignHCenter}
 Action{x:48;y:616;width:624;height:68;label:'连接状态  ›';onClicked:p.connectionRequested()}

 Rectangle{anchors.fill:parent;color:p.color;visible:p.editing!=='';z:2
  Action{x:24;y:30;width:72;height:60;label:'‹';onClicked:p.editing=''}
  FaceText{x:116;y:35;width:500;height:50;text:p.editing==='start'?'开始息屏':'早晨恢复';font.pixelSize:32}
  FaceText{x:100;y:144;width:520;height:126;text:Night.formatMinute(p.editValue);font.pixelSize:104;font.family:'DIN Condensed QP';horizontalAlignment:Text.AlignHCenter}
  Repeater{model:['− 1 小时','+ 1 小时','− 15 分钟','+ 15 分钟']
   Action{x:48+index%2*320;y:318+Math.floor(index/2)*98;width:304;height:78;label:modelData;onClicked:p.shift([-60,60,-15,15][index])}
  }
  FaceText{x:48;y:534;width:624;height:36;text:'时段可以跨越午夜';font.pixelSize:23;color:'#bdc7b6';horizontalAlignment:Text.AlignHCenter}
  Action{x:48;y:612;width:624;height:72;label:'完成';onClicked:p.editing=''}
 }
}
