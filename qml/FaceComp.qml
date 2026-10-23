import QtQuick 2.9
import Qing.Snow 1.0
import 'FaceLogic.js' as F
Item {
 id:c
 property var sensor
 property string sensorKey:''
 property string numberFont:'DIN Condensed QP'
 property int style:0
 property bool night:false
 property bool litBackground:false
 readonly property bool ring:style<3||style===5||style===6
 readonly property bool climate:style===7
 readonly property color ink:night?'#ff5e4e':'#f2f3eb'
 readonly property color muted:night?'#d48679':litBackground?'#d4d8ce':'#a7afa0'
 readonly property color tint:night?'#ff5e4e':F.tint(sensorKey)
 readonly property string value:sensor&&sensor.state!==AirState.PreparingState?sensor.valueString:'—'
 readonly property string unit:sensor?sensor.unitString:''
 signal clicked()
 width:style===1?137:style===3?96:climate?230:128
 height:ring?width:style===3?94:climate?90:96
 Canvas {
  id:g;anchors.fill:parent;visible:c.ring
  onPaint:{var x=getContext('2d');x.clearRect(0,0,width,height);var r=width*64/144,m=width/2,a=Math.PI*.75,b=a+Math.PI*1.5;x.lineWidth=width*6/144;x.lineCap='round';x.beginPath();x.strokeStyle=c.night?'#43261e':'#242c20';x.arc(m,m,r,a,b);x.stroke();if(c.value!=='—'){x.beginPath();x.strokeStyle=c.tint;x.arc(m,m,r,a,a+Math.max(.001,F.ratio(c.sensorKey,c.sensor))*Math.PI*1.5);x.stroke()}}
  Connections{target:c;function onValueChanged(){g.requestPaint()}function onTintChanged(){g.requestPaint()}}
 }
 Rectangle{visible:c.climate;width:parent.width;height:1;color:'#30392b'}
 FaceText{x:0;y:c.ring?16:0;width:c.width;height:c.ring?26:28;text:F.label(c.sensorKey);font.pixelSize:c.ring?20:18;color:c.muted;horizontalAlignment:c.climate?Text.AlignLeft:Text.AlignHCenter}
 FaceText{x:0;y:c.ring?42:c.climate?32:30;width:c.climate?145:c.width;height:c.ring?48:style===3?38:44;text:c.value;font.family:c.numberFont;font.pixelSize:c.value.length>4?(style===3?30:37):(style===3?34:44);color:c.ink;horizontalAlignment:c.climate?Text.AlignLeft:Text.AlignHCenter;fontSizeMode:Text.Fit;minimumPixelSize:27}
 FaceText{x:c.climate?145:0;y:c.ring?92:c.climate?48:style===3?73:79;width:c.climate?85:c.width;height:24;text:c.unit;font.pixelSize:style===3?16:17;color:c.muted;horizontalAlignment:c.climate?Text.AlignRight:Text.AlignHCenter}
 MouseArea{anchors.fill:parent;onClicked:c.clicked()}
}
