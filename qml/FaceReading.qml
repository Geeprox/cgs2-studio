import QtQuick 2.9
import Qing.Snow 1.0
import 'FaceLogic.js' as F
Item {
 id:r
 property var sensor
 property string sensorKey:''
 property int style:0 // 0 horizontal, 1 vertical dial, 2 compact circle, 3 module, 4 XL, 6 chrono, 7 climate
 property bool night:false
 property bool litBackground:false
 property string numberFont:'DIN Condensed QP'
 property var samples:[]
 readonly property string value:sensor&&sensor.state!==AirState.PreparingState?sensor.valueString:'—'
 readonly property color ink:style===1?'#273021':night?'#ff5e4e':'#f2f3eb'
 readonly property color muted:style===1?'#5c6953':night?'#d48679':litBackground?'#d4d8ce':'#a7afa0'
 readonly property color tint:night?'#ff5e4e':F.tint(sensorKey)
 readonly property bool stacked:style===1||style===2||style===6
 TextMetrics{id:numberMetrics;font:number.font;text:r.value}
 TextMetrics{id:unitMetrics;font:unit.font;text:r.sensor?r.sensor.unitString:''}
 signal clicked()
 Rectangle{anchors.fill:parent;visible:r.style===3;color:'#131910';radius:25;border.width:1;border.color:'#333d2c'}
 Rectangle{anchors.fill:parent;visible:r.style===2;color:'transparent';radius:width/2;border.width:3;border.color:r.tint}
 Rectangle{width:parent.width;height:1;y:parent.height-1;visible:r.style===0;color:r.night?'#48271f':'#343d2d'}
 FaceText{
  x:r.style===3?22:0;y:r.style===1?0:r.style===2?13:r.style===3?12:r.style===4?0:r.style===6?6:0
  width:r.stacked?parent.width:r.style===3?220:r.style===4?300:100;height:r.style===1?29:r.style===2?24:34
  text:F.label(r.sensorKey);color:r.muted;font.pixelSize:r.style===4?30:r.style===2?20:23
  horizontalAlignment:r.style===1||r.style===2?Text.AlignHCenter:Text.AlignLeft
  verticalAlignment:r.style===0||r.style===7?Text.AlignBottom:Text.AlignVCenter
  anchors.verticalCenter:r.style===0||r.style===7?parent.verticalCenter:undefined
 }
 Item {
  id:reading
  x:r.style===3?22:r.style===0?110:r.style===7?120:0
  y:r.style===1?29:r.style===2?39:r.style===3?49:r.style===4?42:r.style===6?42:0
  height:r.style===1?132:r.style===2?76:r.style===3?82:r.style===4?190:r.style===6?144:parent.height
  width:r.style===4?230:r.stacked?r.width:numberMetrics.advanceWidth+2+10+unitMetrics.advanceWidth+12
  FaceText{
   id:number;width:r.style===4?230:r.stacked?r.width:numberMetrics.advanceWidth+2;height:r.style===1?105:r.style===2?56:r.style===3?78:r.style===4?190:r.style===6?88:parent.height
   fontSizeMode:Text.Fit;minimumPixelSize:60;text:r.value;font.family:r.numberFont;color:r.ink;font.pixelSize:r.style===1?(r.value.length>4?75:100):r.style===2?(r.value.length>4?38:54):r.style===3?(r.value.length>4?60:72):r.style===4?(r.value.length>4?130:174):r.style===6?(r.value.length>4?64:88):r.style===7?(r.value.length>4?68:98):(r.value.length>4?58:76)
   horizontalAlignment:r.style===1||r.style===2?Text.AlignHCenter:Text.AlignLeft
  }
  FaceText{
   id:unit;x:r.style===4?0:r.stacked?0:number.width+10;y:r.style===4?164:r.style===1?105:r.style===2?56:r.style===6?94:0
   width:r.style===4?230:r.stacked?r.width:unitMetrics.advanceWidth+12;height:r.style===4?30:r.stacked?27:parent.height
   text:r.sensor?r.sensor.unitString:'';color:r.muted;font.pixelSize:r.style===2?17:r.style===4?26:20
   horizontalAlignment:r.style===1||r.style===2?Text.AlignHCenter:Text.AlignLeft
   verticalAlignment:r.stacked?Text.AlignVCenter:Text.AlignBottom
   bottomPadding:r.style===0?21:r.style===3?11:r.style===4?0:r.style===7?14:0
  }
 }
 FaceText{
  x:r.style===1?0:r.style===3?width*0+parent.width-208:r.style===4?0:r.style===6?116:parent.width-146
  y:r.style===1?163:r.style===3?12:r.style===4?46:r.style===6?9:8
  width:r.style===1?parent.width:r.style===3?186:r.style===4?parent.width:r.style===6?120:146;height:30
  visible:r.style!==2
  text:r.sensor?(r.value==='—'?'预热中':r.sensor.evalutionDescription):''
  color:r.style===1?'#3b4b30':r.night?r.tint:(r.sensor?r.sensor.evalutionColor:r.tint)
  font.pixelSize:r.style===4?0:21;horizontalAlignment:r.style===1?Text.AlignHCenter:Text.AlignRight
 }
 Trend {
  visible:r.style!==1&&r.style!==2
  x:r.style===3?parent.width-226:r.style===4?248:r.style===6?0:parent.width-210
  y:r.style===3?50:r.style===4?98:r.style===6?144:35
  width:r.style===3?204:r.style===4?280:r.style===6?parent.width:210
  height:r.style===3?78:r.style===4?138:r.style===6?80:62
  samples:r.samples;sensorKey:r.sensorKey;sensor:r.sensor;ink:r.tint
 }
 MouseArea{anchors.fill:parent;onClicked:r.clicked()}
}
