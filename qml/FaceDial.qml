import QtQuick 2.9
import 'FaceLogic.js' as F
Canvas {
 id:d
 property bool analogue:false
 property date clock:new Date()
 property string sensorKey:'airPM25'
 property var sensor
 property real sensorRatio:F.ratio(sensorKey,sensor)
 onClockChanged:requestPaint()
 onSensorRatioChanged:requestPaint()
 onSensorKeyChanged:requestPaint()
 onAnalogueChanged:requestPaint()
 onPaint:{
  var c=getContext('2d');c.clearRect(0,0,width,height);c.save();c.scale(width/306,height/306)
  c.fillStyle='#f1f1e8';c.beginPath();c.arc(153,153,152,0,Math.PI*2);c.fill();c.lineCap='butt'
  if(!analogue){c.fillStyle='#e4e7dc';c.beginPath();c.arc(153,153,111,0,Math.PI*2);c.fill();c.strokeStyle='#c8cec0';c.lineWidth=1;c.beginPath();c.arc(153,153,105,0,Math.PI*2);c.stroke();c.strokeStyle='#b4c49b';c.lineWidth=5;c.beginPath();c.arc(153,153,147,Math.PI*.75,Math.PI*2.25);c.stroke()}
  var count=analogue?60:40
  for(var i=0;i<(analogue?60:41);i++){var a=(analogue?i*6-90:135+i*6.75)*Math.PI/180,major=i%5===0,inner=analogue?(major?130:137):(major?123:131),outer=analogue?148:143;c.strokeStyle=major?'#343d30':'#959c90';c.lineWidth=major?3:1.7;c.beginPath();c.moveTo(153+Math.cos(a)*inner,153+Math.sin(a)*inner);c.lineTo(153+Math.cos(a)*outer,153+Math.sin(a)*outer);c.stroke()}
  c.textAlign='center';c.textBaseline='middle'
  if(analogue){
   c.fillStyle='#394432';c.font='20px sans-serif';var nums=[12,3,6,9];for(var n=0;n<4;n++){var ra=(n*90-90)*Math.PI/180;c.fillText(String(nums[n]),153+Math.cos(ra)*120,153+Math.sin(ra)*120)}
   c.fillStyle='#68775c';c.font='17px sans-serif';c.fillText(Qt.formatDate(clock,'ddd dd').toUpperCase(),153,202)
   var angles=[((clock.getHours()%12)+clock.getMinutes()/60)*30-90,(clock.getMinutes()+clock.getSeconds()/60)*6-90],lengths=[71,105];c.strokeStyle='#31392d';c.lineCap='round';for(var h=0;h<2;h++){var t=angles[h]*Math.PI/180;c.lineWidth=h===0?9:5;c.beginPath();c.moveTo(153,153);c.lineTo(153+Math.cos(t)*lengths[h],153+Math.sin(t)*lengths[h]);c.stroke()}var sec=(clock.getSeconds()*6-90)*Math.PI/180;c.strokeStyle='#ac4c25';c.lineWidth=2.3;c.beginPath();c.moveTo(153-Math.cos(sec)*20,153-Math.sin(sec)*20);c.lineTo(153+Math.cos(sec)*121,153+Math.sin(sec)*121);c.stroke();c.fillStyle='#ac4c25';c.beginPath();c.arc(153,153,4,0,Math.PI*2);c.fill()
  }else{
   var at=(135+270*sensorRatio)*Math.PI/180;c.strokeStyle='#f37828';c.lineWidth=7;c.lineCap='round';c.beginPath();c.moveTo(153+Math.cos(at)*119,153+Math.sin(at)*119);c.lineTo(153+Math.cos(at)*142,153+Math.sin(at)*142);c.stroke()
   var r=F.range(sensorKey,sensor),str=r[0]+' — '+r[1]+' '+(sensor?sensor.unitString:''),radius=132;c.font='15px sans-serif';c.fillStyle='#626d59';var length=c.measureText(str).width,cursor=-length/2
   for(var k=0;k<str.length;k++){var w=c.measureText(str[k]).width,theta=(cursor+w/2)/radius;c.save();c.translate(153+Math.sin(theta)*radius,153+Math.cos(theta)*radius);c.rotate(-theta);c.fillText(str[k],0,0);c.restore();cursor+=w}
  }
  c.restore()
 }
}
