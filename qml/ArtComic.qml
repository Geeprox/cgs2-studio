import QtQuick 2.9
Item{
 id:v;property var host
 readonly property var keys:host?host.keys:[]
 Rectangle{anchors.fill:parent;color:'#f6e6bd'}
 Canvas{anchors.fill:parent;onPaint:{var c=getContext('2d');c.clearRect(0,0,720,720);c.fillStyle='#f2b93c';c.beginPath();c.moveTo(0,0);c.lineTo(720,0);c.lineTo(720,124);c.quadraticCurveTo(350,96,0,135);c.closePath();c.fill();c.strokeStyle='#17242b';c.lineWidth=4;c.beginPath();c.moveTo(0,131);c.quadraticCurveTo(350,92,720,125);c.stroke();c.fillStyle='#fff9e9';c.beginPath();c.moveTo(53,155);c.quadraticCurveTo(365,132,663,157);c.lineTo(652,354);c.quadraticCurveTo(358,372,48,351);c.closePath();c.fill();c.lineWidth=4;c.stroke();c.fillStyle='#ec6744';c.fillRect(55,148,78,8)}}
 ArtText{x:53;y:41;width:280;height:38;text:host?host.dateLabel():'';font.pixelSize:25;font.weight:Font.Bold}
 ArtText{objectName:'seconds-display';property string secondsRole:'digital';visible:host&&host.secondsMode==='digital';x:358;y:29;width:310;height:74;text:host?Qt.formatTime(host.clock,'HH:mm:ss'):'';font.family:host?host.hand:'';font.pixelSize:43;rotation:2;horizontalAlignment:Text.AlignRight}
 ArtText{x:78;y:166;width:260;height:36;text:host?host.label(host.primaryKey):'';font.pixelSize:25;font.weight:Font.Bold}
 ArtText{x:70;y:207;width:242;height:127;text:host?host.value(host.primaryKey):'';scale:host?host.primaryEmphasis:1;font.family:host?host.hand:'';font.pixelSize:112;fontSizeMode:Text.Fit;minimumPixelSize:58;rotation:-3}
 ArtText{x:319;y:168;width:312;height:35;text:host&&host.primary?host.primary.evalutionDescription:'';font.pixelSize:24;horizontalAlignment:Text.AlignRight}
 ArtText{x:79;y:319;width:234;height:26;text:host?host.unit(host.primaryKey):'';font.pixelSize:19}
 Trend{x:341;y:224;width:280;height:112;sensorKey:host?host.primaryKey:'';sensor:host?host.primary:null;samples:host?host.samples:[];ink:'#2468a5'}
 MouseArea{x:48;y:145;width:616;height:216;onClicked:host.history()}
 Repeater{model:v.keys
  Item{
   id:sticker;x:index%2===0?53:382;y:391+Math.floor(index/2)*87;width:281;height:75;rotation:index%2===0?-1.5:1.4
   readonly property string key:modelData
   Canvas{anchors.fill:parent;onPaint:{var c=getContext('2d');c.clearRect(0,0,width,height);c.fillStyle=['#f0b855','#bed8c6','#e6b2ac','#c4d9e5','#edcf83','#c1c6df'][index];c.strokeStyle='#17242b';c.lineWidth=3;c.beginPath();c.moveTo(3,6);c.lineTo(width-7,2);c.lineTo(width-2,height-8);c.lineTo(7,height-2);c.closePath();c.fill();c.stroke()}}
   ArtText{x:15;y:7;width:108;height:27;text:host?host.label(sticker.key):'';font.pixelSize:20;font.weight:Font.Bold}
   ArtText{x:125;y:0;width:137;height:51;text:host?host.value(sticker.key):'';font.family:host?host.hand:'';font.pixelSize:42;fontSizeMode:Text.Fit;minimumPixelSize:28;horizontalAlignment:Text.AlignRight}
   ArtText{x:116;y:46;width:146;height:24;text:host?host.unit(sticker.key):'';font.pixelSize:18;horizontalAlignment:Text.AlignRight}
   MouseArea{anchors.fill:parent;onClicked:host.choose(sticker.key)}
  }
 }
}
