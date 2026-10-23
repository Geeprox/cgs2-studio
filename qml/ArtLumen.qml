import QtQuick 2.9
Item {
 id:v
 property var host
 readonly property var keys:host?host.keys:[]
 readonly property var accents:['#e9b86b','#8ec6b2','#d49c87','#94c7d0','#a7b8da','#c8cc83']
 Rectangle{anchors.fill:parent;color:'#101e22'}
 ArtText{x:53;y:33;width:270;height:75;text:host?Qt.formatTime(host.clock,'HH:mm'):'';font.family:host?host.tech:'';font.pixelSize:72;color:'#eef2e6'}
 ArtText{x:397;y:48;width:267;height:34;text:host?host.dateLabel():'';font.pixelSize:22;color:'#a5bab9';horizontalAlignment:Text.AlignRight}
 ArtText{x:58;y:154;width:246;height:39;text:host?host.label(host.primaryKey):'';font.pixelSize:28;color:'#a5bab9'}
 ArtText{x:54;y:192;width:253;height:123;text:host?host.value(host.primaryKey):'';font.family:host?host.tech:'';font.pixelSize:118;fontSizeMode:Text.Fit;minimumPixelSize:64;color:'#eef2e6';scale:host?host.primaryEmphasis:1}
 ArtText{x:59;y:314;width:237;height:30;text:host?host.unit(host.primaryKey):'';font.pixelSize:21;color:'#a5bab9'}
 Canvas {
  id:horizon;x:324;y:143;width:346;height:207
  onPaint:{
   var c=getContext('2d');c.clearRect(0,0,width,height);
   var cx=173,cy=161,r=134,ratio=v.host?v.host.ratio(v.host.primaryKey):0;
   c.lineCap='round';
   for(var glow=4;glow>=1;glow--){c.strokeStyle='#dfb575';c.globalAlpha=.013*glow;c.lineWidth=15+glow*11;c.beginPath();c.arc(cx,cy,r,Math.PI,Math.PI*2);c.stroke()}
   c.globalAlpha=1;var g=c.createLinearGradient(34,cy,312,cy);g.addColorStop(0,'#657c72');g.addColorStop(.45,'#b9c4a4');g.addColorStop(1,'#e2ad65');c.strokeStyle=g;c.lineWidth=14;c.beginPath();c.arc(cx,cy,r,Math.PI,Math.PI*2);c.stroke();
   c.strokeStyle='#77908d';c.lineWidth=1;for(var n=0;n<=20;n++){var a=Math.PI+n*Math.PI/20;c.beginPath();c.moveTo(cx+Math.cos(a)*(r-20),cy+Math.sin(a)*(r-20));c.lineTo(cx+Math.cos(a)*(r-20-(n%5===0?11:4)),cy+Math.sin(a)*(r-20-(n%5===0?11:4)));c.stroke()}
   var a=Math.PI+ratio*Math.PI,px=cx+Math.cos(a)*r,py=cy+Math.sin(a)*r;
   for(var h=4;h>=1;h--){c.fillStyle='#f1cc8c';c.globalAlpha=.026*h;c.beginPath();c.arc(px,py,9+h*5,0,Math.PI*2);c.fill()}
   c.globalAlpha=1;c.fillStyle='#fcf2d4';c.beginPath();c.arc(px,py,8,0,Math.PI*2);c.fill();c.strokeStyle='#25332e';c.lineWidth=2;c.stroke();
  }
  Connections{target:v.host||null;ignoreUnknownSignals:true;function onPrimaryKeyChanged(){horizon.requestPaint()}}
  Connections{target:v.host?v.host.primary:null;ignoreUnknownSignals:true;function onValueStringChanged(){horizon.requestPaint()}}
 }
 ArtText{x:354;y:315;width:90;height:29;text:host?String(host.range(host.primaryKey)[0]):'';font.pixelSize:18;color:'#8da4a1'}
 ArtText{x:571;y:315;width:83;height:29;text:host?String(host.range(host.primaryKey)[1]):'';font.pixelSize:18;color:'#8da4a1';horizontalAlignment:Text.AlignRight}
 ArtText{x:408;y:269;width:177;height:36;text:host&&host.primary?host.primary.evalutionDescription:'';font.pixelSize:25;color:'#e0c293';horizontalAlignment:Text.AlignHCenter}
 MouseArea{x:48;y:139;width:624;height:217;onClicked:host.history()}
 Repeater {
  model:v.keys
  Item {
   id:meter;x:index%2===0?50:374;y:383+Math.floor(index/2)*87;width:296;height:77
   readonly property string key:modelData
   readonly property color accent:v.accents[index]
   Rectangle{anchors.fill:parent;radius:18;border.width:1;border.color:'#32464b';gradient:Gradient{GradientStop{position:0;color:'#24373c'}GradientStop{position:1;color:'#14262b'}}}
   ArtText{x:18;y:7;width:153;height:27;text:host?host.label(meter.key):'';font.pixelSize:20;color:'#c0cecb'}
   ArtText{x:170;y:3;width:109;height:43;text:host?host.value(meter.key):'';font.family:host?host.tech:'';font.pixelSize:41;fontSizeMode:Text.Fit;minimumPixelSize:28;color:'#eef2e6';horizontalAlignment:Text.AlignRight}
   ArtText{x:160;y:46;width:118;height:23;text:host?host.unit(meter.key):'';font.pixelSize:17;color:'#a5bab9';horizontalAlignment:Text.AlignRight}
   Rectangle{x:19;y:51;width:126;height:6;radius:3;color:'#101c20'}
   Rectangle{x:19;y:51;width:host?Math.max(4,126*host.ratio(meter.key)):4;height:6;radius:3;color:meter.accent}
   Rectangle{x:19;y:49;width:host?Math.max(4,126*host.ratio(meter.key)):4;height:10;radius:5;color:meter.accent;opacity:.13}
   MouseArea{anchors.fill:parent;onClicked:host.choose(meter.key)}
  }
 }
}
