import QtQuick 2.9
import 'FaceLogic.js' as F
Canvas{
 id:r
 property date clock:new Date()
 property color ink:'#ff9b45'
 property bool subtle:false
 onClockChanged:requestPaint()
 onInkChanged:requestPaint()
 onPaint:{var c=getContext('2d');c.clearRect(0,0,width,height);c.save();c.scale(width/720,height/720);var m=F.rimMark(clock.getSeconds()/60,34);c.strokeStyle=r.ink;c.lineWidth=subtle?4:5;c.lineCap='round';c.beginPath();c.moveTo(m[0],m[1]);c.lineTo(m[2],m[3]);c.stroke();c.restore()}
}
