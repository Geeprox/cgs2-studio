import QtQuick 2.9
import "MicroGesture.js" as Gesture
Rectangle {
 id:p;color:"#eff0eb"
 property var store
 property color accent:"#ff8a32"
 property int selectedSlot:-1
 property string localFeedback:""
 property real knobAngle:0
 property bool voiceHeld:false
 property bool voiceReleasePending:false
 property int releaseAt:0
 function releaseVoice(){if(!voiceHeld)return;voiceHeld=false;voiceReleasePending=true;releaseAt=store?store.uptime:0}
 Timer{interval:200;running:p.visible;repeat:true;onTriggered:{if(!p.store)return;if(p.voiceReleasePending){if(p.store.uptime-p.releaseAt>3)p.voiceReleasePending=false;else if(p.ready&&p.store.pending===""){p.store.command("key",{key:"voice",pressed:false});p.voiceReleasePending=false}}}}
 Timer{interval:1000;running:p.voiceHeld&&p.visible;repeat:true;onTriggered:if(p.ready&&p.store.pending==="")p.store.command("key",{key:"voice",pressed:true})}
 Component.onDestruction:if(voiceHeld)releaseVoice()
 signal closed()
 readonly property bool ready:store&&store.online
 readonly property var caps:ready?(store.micro.capabilities||{}):({})
 function keyAvailable(k){return !!(p.ready&&p.store.micro.keyAvailable&&p.store.micro.keyAvailable[k]===true&&p.store.pending==="")}
 function slot(k){return p.ready&&p.store.micro.slots?p.store.micro.slots[k]:null}
 function glow(s){return s==="running"?"#86aeff":s==="complete"?"#91d894":s==="waiting"?"#efbe66":s==="error"?"#ef8382":s==="idle"?"#f5f8e8":"#b9c2b7"}
 function stateName(s){return s==="running"?"运行中":s==="complete"?"已完成":s==="waiting"?"等待操作":s==="error"?"错误":s==="idle"?"空闲":"未知"}
 function binding(k){return p.ready&&p.store.micro.layout?p.store.micro.layout[k]:null}
 function keyIcon(k,fallback){var b=binding(k);return b&&b.action==="app"?"":b&&b.icon!=="none"?b.icon:fallback}
 function appIcon(k){var b=binding(k);return b&&b.action==="app"&&p.store.micro.appIcons?(p.store.micro.appIcons[b.appId]||""):""}
 function pressKey(k){
  if(!p.ready){p.localFeedback="请检查 Wi-Fi、NAS 与 Mac 的连接";return}
  if(!keyAvailable(k)){p.localFeedback=k==="voice"?"语音尚不可用；当前未采集麦克风。":"此键尚未配置可用动作";return}
  p.localFeedback=""
  var b=binding(k)
  if(b&&/^agent[0-5]$/.test(b.action)){var i=Number(b.action.slice(5)),s=slot(i);p.selectedSlot=s?i:-1}
  p.store.command("key",{key:k})
 }
 readonly property color caseLight:{
  if(!p.ready||!p.store.micro.slots)return "#c8cfc4"
  var states=p.store.micro.slots.map(function(s){return s.status})
  var order=["error","waiting","running","complete","idle"]
  for(var i=0;i<order.length;i++)if(states.indexOf(order[i])>=0)return p.glow(order[i])
  return "#c8cfc4"
 }
 Rectangle { x:24;y:25;width:64;height:57;radius:17;color:back.pressed?"#d9ddd4":"#e2e5dc";Text{anchors.centerIn:parent;text:"‹";color:"#30382e";font.pixelSize:36}MouseArea{id:back;anchors.fill:parent;onClicked:p.closed()} }
 Text { x:109;y:22;width:365;height:36;text:"Codex Micro";color:"#29342b";font.pixelSize:31;font.weight:Font.Medium }
 Text { x:110;y:61;width:440;height:24;text:p.ready?"MAC MINI · Wi-Fi 局域网":"MAC MINI · 未连接";color:"#737e6b";font.pixelSize:16 }
 Rectangle { x:570;y:30;width:126;height:45;radius:13;color:refresh.pressed?"#d9ddd4":"#e2e5dc";Text{anchors.centerIn:parent;text:"自动刷新";color:"#394632";font.pixelSize:19}MouseArea{id:refresh;anchors.fill:parent;onClicked:if(p.store)p.store.poll()} }
 Rectangle {
  x:80;y:96;width:560;height:560;radius:65
  gradient:Gradient { GradientStop{position:0;color:"#fcfdf8"}GradientStop{position:.5;color:"#e3e8df"}GradientStop{position:1;color:"#c8d1c3"} }
  border.width:6;border.color:p.caseLight
  Rectangle { x:12;y:12;width:536;height:536;radius:55;color:"transparent";border.width:2;border.color:"#ffffff";opacity:.85 }
  Rectangle {
   id:plate;x:28;y:28;width:504;height:504;radius:25;border.width:2;border.color:"#aeb8a6"
   gradient:Gradient { GradientStop{position:0;color:"#d9ded5"}GradientStop{position:.45;color:"#f6f8ef"}GradientStop{position:1;color:"#cdd5c7"} }
   Repeater { model:4
    Rectangle { x:index%2===0?8:466;y:index<2?8:466;width:30;height:30;radius:15;color:"#414b3b";border.width:2;border.color:"#818b77";Rectangle { anchors.centerIn:parent;width:12;height:12;rotation:45;radius:2;color:"#192113" } }
   }
   Text { x:226;y:2;width:52;height:34;text:"↑";color:"#33402e";font.pixelSize:28;horizontalAlignment:Text.AlignHCenter }
   Text { x:-98;y:250;width:230;height:18;rotation:-90;text:"CGS2 Studio | Desktop Control";color:"#59654f";font.pixelSize:12;horizontalAlignment:Text.AlignHCenter }
   Text { x:372;y:250;width:230;height:18;rotation:90;text:"You can just build things";color:"#59654f";font.pixelSize:12;horizontalAlignment:Text.AlignHCenter }
   Text { x:176;y:479;width:152;height:24;text:"Let's build";color:"#66745b";font.pixelSize:16;horizontalAlignment:Text.AlignHCenter }
   Item {
    x:38;y:40;width:428;height:428
    // Same four-by-four physical arrangement as macremote's Micro panel.
    Rectangle {
     id:dial;x:0;y:0;width:98;height:98;radius:49;rotation:p.knobAngle
     gradient:Gradient { GradientStop{position:0;color:"#ffffff"}GradientStop{position:.6;color:"#e4eade"}GradientStop{position:1;color:"#bbc8af"} }
     border.width:1;border.color:"#ffffff"
     Rectangle { x:14;y:41;width:70;height:16;radius:6;rotation:-45;color:"#a5b39c";border.width:1;border.color:"#dfe7d7" }
     Rectangle { x:46;y:7;width:4;height:10;radius:2;color:"#99a68f" }
     MouseArea { id:dialTouch;objectName:"micro-dial-touch";anchors.fill:parent;preventStealing:true;propagateComposedEvents:false;property real startX:0;onPressed:{mouse.accepted=true;startX=mapToItem(p,mouse.x,mouse.y).x;p.localFeedback="旋转 · 每次松手调节一级"}onPositionChanged:if(pressed){var dx=mapToItem(p,mouse.x,mouse.y).x-startX;p.knobAngle=Math.max(-60,Math.min(60,Math.round(dx/12)*12))}onReleased:{var dx=mapToItem(p,mouse.x,mouse.y).x-startX;p.knobAngle=0;if(!p.visible)return;if(Math.abs(dx)>18){if(p.ready&&p.caps.reasoning&&p.store.pending===""){p.localFeedback="";p.store.command("reasoning",{delta:dx>0?1:-1})}else p.localFeedback="推理旋钮尚未就绪"}else p.localFeedback="左右旋转调节推理强度"}onCanceled:p.knobAngle=0 }
     Behavior on rotation { NumberAnimation { duration:65 } }
    }
    Repeater {
     model:6
     MicroKey {
      property string keyId:"agent"+index
      property var savedBinding:p.binding(keyId)
      property int mappedIndex:savedBinding&&/^agent[0-5]$/.test(savedBinding.action)?Number(savedBinding.action.slice(5)):index
      property var assigned:p.slot(mappedIndex)
      x:index<2?110*(index+1):110*(index-2);y:index<2?0:110
      agent:!savedBinding||/^agent[0-5]$/.test(savedBinding.action);agentIndex:mappedIndex;status:assigned?assigned.status:"unknown";light:assigned?p.glow(assigned.status):"#bbc4b7"
      available:p.keyAvailable(keyId)
      icon:p.keyIcon(keyId,"")
      label:savedBinding?savedBinding.label:""
      appIcon:savedBinding&&savedBinding.action==="app"&&p.store.micro.appIcons?(p.store.micro.appIcons[savedBinding.appId]||""):""
      onClicked:p.pressKey(keyId)
     }
    }
    Rectangle {
     x:330;y:0;width:98;height:98;radius:15;color:"#929e87";border.width:2;border.color:"#38462e"
     Rectangle { x:5;y:5;width:88;height:88;radius:20;color:"#e0e6d8";border.width:2;border.color:"#f8fbf4" }
     Rectangle {
      id:stick;x:10+joy.dx;y:10+joy.dy;width:78;height:78;radius:39
      Behavior on x{NumberAnimation{duration:joy.pressed?25:180;easing.type:joy.pressed?Easing.Linear:Easing.OutBack}}
      Behavior on y{NumberAnimation{duration:joy.pressed?25:180;easing.type:joy.pressed?Easing.Linear:Easing.OutBack}}
      gradient:Gradient{GradientStop{position:0;color:"#414c38"}GradientStop{position:1;color:"#141e0d"}}border.width:1;border.color:"#0a1304"
      Repeater { model:4;Rectangle { x:index===1?52:index===3?13:33;y:index===0?14:index===2?61:35;width:12;height:2;rotation:index%2===0?45:-45;color:"#101a08" } }
     }
     MouseArea { id:joy;objectName:"micro-joystick-touch";anchors.fill:parent;preventStealing:true;propagateComposedEvents:false
      property real sx:0;property real sy:0;property real dx:0;property real dy:0;property string lockedAxis:""
      onPressed:{mouse.accepted=true;sx=mouse.x;sy=mouse.y;dx=0;dy=0;lockedAxis=""}
      onPositionChanged:{if(!pressed)return;var a=mouse.x-sx,b=mouse.y-sy,q=Gesture.vector(a,b);lockedAxis=Gesture.axis(a,b,lockedAxis);dx=q.x;dy=q.y}
      onReleased:{var key=Gesture.direction(mouse.x-sx,mouse.y-sy,lockedAxis);dx=0;dy=0;lockedAxis="";if(!p.visible)return;if(key)p.pressKey(key);else p.localFeedback="滑动摇杆选择方向，松开执行"}
      onCanceled:{dx=0;dy=0;lockedAxis=""}
     }
    }
    Repeater {
     model:[{key:"fast",icon:"skill"},{key:"approve",icon:"accept"},{key:"reject",icon:"reject"},{key:"fork",icon:"newTask"}]
     MicroKey { x:index*110;y:220;appIcon:p.appIcon(modelData.key);label:p.binding(modelData.key)?p.binding(modelData.key).label:"";icon:p.keyIcon(modelData.key,modelData.icon);available:p.keyAvailable(modelData.key);onClicked:p.pressKey(modelData.key) }
    }
    Item { x:0;y:330;width:98;height:98
     Repeater{model:3;Rectangle{x:0;y:24+index*20;width:9;height:5;rotation:8;color:index===0?"#e4e9cc":"#87957a";border.width:1;border.color:"#627252"}}
     Rectangle { x:20;y:12;width:76;height:76;radius:38;color:"#c4cebb";border.width:2;border.color:"#94a483";Rectangle { anchors.centerIn:parent;width:53;height:53;radius:27;color:"#0c1308" } }
    }
    MicroKey { x:110;y:330;width:208;height:98;appIcon:p.appIcon("voice");icon:p.keyIcon("voice","voice");available:p.keyAvailable("voice");holdMode:!!(p.binding("voice")&&p.binding("voice").action==="voice");onClicked:p.pressKey("voice");onHeld:{if(p.keyAvailable("voice")){p.voiceHeld=true;p.voiceReleasePending=false;p.localFeedback="按住听写 · 使用 Mac 的麦克风";p.store.command("key",{key:"voice",pressed:true})}else p.localFeedback="Mac 听写尚未就绪"}onReleased:p.releaseVoice() }
    MicroKey { x:330;y:330;appIcon:p.appIcon("submit");icon:p.keyIcon("submit","codex");available:p.keyAvailable("submit");onClicked:p.pressKey("submit") }
   }
  }
 }
 Text { x:44;y:672;width:632;height:32;visible:p.localFeedback!==""||(p.store&&p.store.pending!=="")||(p.store&&p.store.feedback!=="");text:p.localFeedback||(p.store&&p.store.pending!==""?"正在执行…":p.selectedSlot>=0&&p.slot(p.selectedSlot)?("0"+(p.selectedSlot+1)+" · "+p.stateName(p.slot(p.selectedSlot).status)+" · "+p.slot(p.selectedSlot).title):(p.store&&p.store.feedback)||"");color:"#59674f";font.pixelSize:20;elide:Text.ElideRight;horizontalAlignment:Text.AlignHCenter }
}
