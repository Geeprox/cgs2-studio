import QtQuick 2.9
Item {
 id:key
 property string icon:""
 property string label:""
 property string appIcon:""
 property bool agent:false
 property int agentIndex:0
 property color light:"#aab2aa"
 property bool available:true
 property string status:"unknown"
 signal held()
 signal released()
 property bool holdMode:false
 signal clicked()
 width:98;height:98
 Rectangle { x:0;y:6;width:parent.width;height:parent.height;radius:21;color:"#818a80";border.width:1;border.color:"#687265" }
 Rectangle {
  id:cap;x:0;y:hit.pressed?4:0;width:parent.width;height:parent.height;radius:21;border.width:1;border.color:"#ffffff"
  gradient:Gradient { GradientStop{position:0;color:key.agent?"#e4e8e3":"#ffffff"}GradientStop{position:.54;color:key.agent?"#cdd3cc":"#eaede6"}GradientStop{position:1;color:"#f5f8f0"} }
  Rectangle { anchors.fill:parent;anchors.margins:7;radius:19;border.width:1;border.color:"#eaf1e6";color:key.agent?key.light:"#dce2d6";opacity:key.agent?.65:.48
   SequentialAnimation on opacity{running:key.agent&&key.status==="running"&&key.visible;loops:Animation.Infinite;NumberAnimation{from:.42;to:.85;duration:650;easing.type:Easing.InOutSine}NumberAnimation{from:.85;to:.42;duration:650;easing.type:Easing.InOutSine}} }
  Rectangle { visible:key.agent;x:24;y:24;width:50;height:50;radius:12;color:key.light;opacity:.8
   Rectangle { x:19;y:9;width:12;height:32;radius:2;color:"#8e9ca7";opacity:.65 }
   Rectangle { x:9;y:19;width:32;height:12;radius:2;color:"#8e9ca7";opacity:.65 }
  }
  Image { visible:key.icon!==""&&key.appIcon==="";anchors.centerIn:parent;width:43;height:43;source:key.icon!==""?"icons/"+key.icon+".svg":"";opacity:key.available?1:.33 }
  Image { visible:key.appIcon!=="";anchors.centerIn:parent;width:56;height:56;source:key.appIcon;fillMode:Image.PreserveAspectFit }
  Text { visible:key.agent;anchors.right:parent.right;anchors.rightMargin:12;anchors.bottom:parent.bottom;anchors.bottomMargin:8;text:"0"+(key.agentIndex+1);font.pixelSize:13;color:"#596655" }
  Text { visible:key.label!=="";anchors.bottom:parent.bottom;anchors.bottomMargin:7;anchors.horizontalCenter:parent.horizontalCenter;text:key.label;font.pixelSize:15;color:key.available?"#35402f":"#8d9589" }
  Behavior on y { NumberAnimation { duration:75 } }
 }
 MouseArea { id:hit;anchors.fill:parent;onClicked:if(!key.holdMode)key.clicked();onPressed:if(key.holdMode)key.held();onReleased:if(key.holdMode)key.released();onCanceled:if(key.holdMode)key.released() }
}
