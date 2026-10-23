import QtQuick 2.9
Rectangle{
 id:c
 objectName:"menu-card"
 property int kind:0
 property string label:''
 property string status:''
 signal clicked()
 radius:22;color:hit.pressed?'#344332':'#1d281c';border.width:1;border.color:hit.pressed?'#a9c69b':'#3d4b36'
 scale:hit.pressed?.97:1
 Behavior on scale{NumberAnimation{duration:90}}
 Canvas{
  x:(parent.width-46)/2;y:20;width:46;height:46
  onPaint:{var p=getContext('2d');p.clearRect(0,0,46,46);p.strokeStyle='#d4dfcb';p.fillStyle='#d4dfcb';p.lineWidth=2.2;p.lineCap='round';p.lineJoin='round';p.beginPath();
   if(c.kind===0){for(var y=0;y<2;y++)for(var x=0;x<2;x++)p.strokeRect(7+x*19,7+y*19,13,13)}
   else if(c.kind===1){p.strokeRect(5,6,36,33);for(var y=0;y<2;y++)for(var x=0;x<3;x++)p.strokeRect(10+x*10,12+y*10,5,5);p.moveTo(12,33);p.lineTo(34,33);p.stroke()}
   else if(c.kind===2){p.strokeRect(5,7,36,31);p.moveTo(7,34);p.lineTo(18,22);p.lineTo(25,29);p.lineTo(31,21);p.lineTo(39,32);p.stroke();p.beginPath();p.arc(16,16,3,0,Math.PI*2);p.stroke()}
   else if(c.kind===3){p.arc(23,23,9,0,Math.PI*2);p.stroke();for(var i=0;i<8;i++){var a=i*Math.PI/4;p.beginPath();p.moveTo(23+Math.cos(a)*15,23+Math.sin(a)*15);p.lineTo(23+Math.cos(a)*20,23+Math.sin(a)*20);p.stroke()}}
   else if(c.kind===4){p.moveTo(16,9);p.lineTo(36,23);p.lineTo(16,37);p.closePath();p.stroke();p.beginPath();p.moveTo(7,12);p.lineTo(7,34);p.stroke()}
   else if(c.kind===5){p.arc(23,24,15,-Math.PI*.7,Math.PI*.9);p.stroke();p.beginPath();p.moveTo(9,9);p.lineTo(10,20);p.lineTo(20,14);p.stroke()}
   else if(c.kind===6){for(var i=0;i<3;i++){p.beginPath();p.arc(23,37,9+i*9,Math.PI*1.24,Math.PI*1.76);p.stroke()}p.beginPath();p.arc(23,37,2.6,0,Math.PI*2);p.fill()}
   else if(c.kind===7){p.moveTo(8,29);p.bezierCurveTo(0,29,1,15,12,16);p.bezierCurveTo(13,2,33,2,35,17);p.bezierCurveTo(46,17,46,30,37,30);p.lineTo(8,30);p.stroke();for(var i=0;i<3;i++){p.beginPath();p.moveTo(14+i*9,35);p.lineTo(11+i*9,40);p.stroke()}}
   else {p.moveTo(20,9);p.lineTo(6,23);p.lineTo(20,37);p.moveTo(7,23);p.lineTo(28,23);p.quadraticCurveTo(39,23,39,36);p.stroke()}
  }
 }
 FaceText{x:8;y:78;width:parent.width-16;height:36;text:c.label;font.pixelSize:23;font.weight:Font.Medium;horizontalAlignment:Text.AlignHCenter;color:'#e4ebdf'}
 FaceText{x:8;y:114;width:parent.width-16;height:25;text:c.status;font.pixelSize:17;horizontalAlignment:Text.AlignHCenter;color:'#afc49f'}
 MouseArea{id:hit;anchors.fill:parent;onClicked:c.clicked()}
}
