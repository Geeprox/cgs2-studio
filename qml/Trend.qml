import QtQuick 2.9
import 'FaceLogic.js' as F
Item {
 id:t
 property var samples:[]
 property string sensorKey:''
 property var sensor
 property color ink:'#b7ed4c'
 readonly property bool ready:samples.length>1
 readonly property real minimum:ready?Math.min.apply(null,samples.map(function(v){return v[1]})):0
 readonly property real maximum:ready?Math.max.apply(null,samples.map(function(v){return v[1]})):1
 readonly property real span:Math.max(F.minimumSpan(sensorKey,sensor),maximum-minimum)
 readonly property real floorValue:(minimum+maximum-span)/2
 readonly property string axis:ready?F.trendAxis(samples):'积累历史中'
 Canvas{
  id:line;x:0;y:0;width:parent.width;height:parent.height-24
  onPaint:{var c=getContext('2d');c.clearRect(0,0,width,height);if(!t.ready)return;var first=t.samples[0][0],last=t.samples[t.samples.length-1][0];c.strokeStyle='#586251';c.globalAlpha=.4;c.lineWidth=1;c.beginPath();c.moveTo(0,height/2);c.lineTo(width,height/2);c.stroke();c.globalAlpha=1;c.strokeStyle=t.ink;c.lineWidth=2.2;c.lineJoin='round';c.beginPath();var prev=0;for(var i=0;i<t.samples.length;i++){var a=t.samples[i],x=(a[0]-first)/Math.max(1,last-first)*(width-4)+2,y=height-4-(a[1]-t.floorValue)/t.span*(height-8);if(i===0||a[0]-prev>1900)c.moveTo(x,y);else c.lineTo(x,y);prev=a[0]}c.stroke()}
 }
 FaceText{x:0;y:parent.height-23;width:parent.width;height:22;text:t.axis;font.pixelSize:13;color:'#a7afa0';horizontalAlignment:Text.AlignRight}
 onSamplesChanged:line.requestPaint()
 onInkChanged:line.requestPaint()
 onWidthChanged:line.requestPaint()
}
