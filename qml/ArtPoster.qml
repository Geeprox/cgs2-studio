import QtQuick 2.9
Item{
 id:v;property var host
 readonly property var keys:host?host.keys:[]
 Rectangle{anchors.fill:parent;color:'#efe8d9'}
 ArtText{x:55;y:37;width:300;height:33;text:host?host.dateLabel():'';font.pixelSize:22;font.weight:Font.Bold}
 Rectangle{x:55;y:108;width:292;height:292;radius:146;color:'#cf452e'}
 Rectangle{x:412;y:109;width:226;height:6;color:'#192323'}
 ArtText{x:427;y:128;width:205;height:121;text:host?Qt.formatTime(host.clock,'HH'):'';font.family:'Roboto';font.weight:Font.Black;font.pixelSize:116;color:'#172421';horizontalAlignment:Text.AlignHCenter}
 ArtText{x:427;y:242;width:205;height:121;text:host?Qt.formatTime(host.clock,'mm'):'';font.family:'Roboto';font.weight:Font.Black;font.pixelSize:116;color:'#172421';horizontalAlignment:Text.AlignHCenter}
 ArtText{x:77;y:135;width:248;height:38;text:host?host.label(host.primaryKey):'';font.pixelSize:25;font.weight:Font.Bold;color:'#fff1d9';horizontalAlignment:Text.AlignHCenter}
 ArtText{x:75;y:177;width:252;height:158;text:host?host.value(host.primaryKey):'';scale:host?host.primaryEmphasis:1;font.family:'Roboto';font.weight:Font.Black;font.pixelSize:132;fontSizeMode:Text.Fit;minimumPixelSize:70;color:'#fff4dc';horizontalAlignment:Text.AlignHCenter}
 ArtText{x:85;y:342;width:232;height:33;text:host?host.unit(host.primaryKey):'';font.pixelSize:22;color:'#fff1d9';horizontalAlignment:Text.AlignHCenter}
 ArtText{x:411;y:370;width:230;height:38;text:host&&host.primary?host.primary.evalutionDescription:'';font.pixelSize:27;font.weight:Font.Bold;color:'#cf452e';horizontalAlignment:Text.AlignHCenter}
 MouseArea{x:55;y:108;width:292;height:292;onClicked:host.history()}
 Repeater{model:v.keys
  Item{
   id:column;x:55+index*102;y:435;width:91;height:196
   readonly property string key:modelData
   ArtText{x:0;y:0;width:91;height:44;text:host?host.value(column.key):'';font.family:'Roboto';font.weight:Font.Bold;font.pixelSize:32;fontSizeMode:Text.Fit;minimumPixelSize:24;horizontalAlignment:Text.AlignHCenter}
   Repeater{model:4;Rectangle{x:25;y:54+index*27;width:41;height:1;color:'#c6c7b9'}}
   Rectangle{x:34;y:54;width:23;height:82;color:'#d0d0c1'}
   Rectangle{x:34;y:host?136-82*host.ratio(column.key):136;width:23;height:host?82*host.ratio(column.key):0;color:index%2===0?'#cf452e':'#315f88'}
   ArtText{x:0;y:143;width:91;height:28;text:host?host.label(column.key):'';font.pixelSize:20;font.weight:Font.Bold;horizontalAlignment:Text.AlignHCenter}
   ArtText{x:0;y:171;width:91;height:24;text:host?host.unit(column.key):'';font.pixelSize:17;color:'#596154';horizontalAlignment:Text.AlignHCenter}
   MouseArea{anchors.fill:parent;onClicked:host.choose(column.key)}
  }
 }
}
