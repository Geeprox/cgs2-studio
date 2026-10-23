import QtQuick 2.9
import 'FaceLogic.js' as F
Rectangle{
 id:p;objectName:'skin-picker';color:'#080c07';property var store;property color accent:'#ff863c';property int page:0;signal closed()
 function anchorCurrent(){if(store)page=store.skin===100?1:Math.min(1,Math.floor(store.skin/8))}
 onStoreChanged:anchorCurrent()
 Component.onCompleted:anchorCurrent()
 FaceText{x:108;y:27;width:450;height:55;text:'表盘';font.pixelSize:32}
 Action{x:24;y:25;width:64;height:58;label:'‹';onClicked:p.closed()}
 Repeater{model:8
  Rectangle{
   readonly property int n:p.page*8+index
   visible:n<14;x:40+index%2*330;y:108+Math.floor(index/2)*112;width:310;height:94;radius:20;color:hit.pressed?'#293323':'#151e11';border.width:p.store&&p.store.skin===n?2:1;border.color:p.store&&p.store.skin===n?p.accent:'#2b3922'
   FaceText{x:22;y:12;width:264;height:36;text:F.names[n]||'';font.pixelSize:24}
   FaceText{x:22;y:51;width:264;height:28;text:p.store&&p.store.skin===n?'当前表盘':'轻点切换';font.pixelSize:16;color:'#89957e'}
   MouseArea{id:hit;anchors.fill:parent;onClicked:{p.store.chooseSkin(parent.n);p.closed()}}
  }
 }
 Action{x:100;y:586;width:160;height:60;label:'‹ 上一页';enabled:p.page>0;onClicked:p.page--}
 FaceText{x:290;y:600;width:140;height:40;text:(p.page+1)+' / 2';font.pixelSize:22;horizontalAlignment:Text.AlignHCenter}
 Action{x:460;y:586;width:160;height:60;label:'下一页 ›';enabled:p.page<1;onClicked:p.page++}
 FaceText{x:50;y:670;width:620;height:26;text:'点小参数替换主显示 · 点主显示查看历史';font.pixelSize:17;color:'#87947a';horizontalAlignment:Text.AlignHCenter}
}
