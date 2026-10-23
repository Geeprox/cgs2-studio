import QtQuick 2.9
import 'WeatherSky.js' as Sky
import 'MoonPhase.js' as Lunar
Canvas {
 id:w
 property string sky:''
 // Weather is a background, below text, charts and complications.
 property bool ambient:false
 property bool artwork:false
 property bool running:true
 property date clock:new Date()
 property bool automaticClock:true
 readonly property real clockMinute:Math.floor(clock.getTime()/60000)
 readonly property var moonState:Lunar.at(clockMinute*60000)
 property bool diagnostics:false
 signal benchmark(var metrics)
 PaintProbe{id:probe;enabled:w.diagnostics&&w.running&&w.visible;sourceName:'weather-background';onSample:{metrics.kind=w.scene;w.benchmark(metrics)}}
 onPainted:probe.painted()
 onAvailableChanged:if(available)requestPaint()
 onVisibleChanged:if(visible)requestPaint()
 onRunningChanged:if(visible)requestPaint()
 property real phase:0
 readonly property string kind:sky.toLowerCase()
 readonly property string scene:Sky.scene(sky)
 readonly property string sceneLabel:Sky.label(sky)
 readonly property bool night:Sky.isNight(sky)
 readonly property bool overcast:Sky.isOvercast(sky)
 readonly property bool thunder:Sky.isThunder(sky)
 readonly property bool lunarScene:scene==='night'||scene==='cloud'&&night
 // Ordinary rain/snow motion belongs to the bounded particle layer. Lightning
 // needs the 10 Hz backdrop timer; clear skies use only 5 Hz.
 readonly property bool animateBackdrop:scene!=='none'&&(scene!=='rain'||thunder)&&scene!=='snow'
 Timer{interval:scene==='sun'||scene==='night'?200:100;running:w.running&&w.visible&&w.animateBackdrop;repeat:true;onTriggered:{w.phase+=(interval/1000);w.requestPaint()}}
 Timer{interval:60000;running:w.automaticClock&&w.running&&w.visible&&w.lunarScene;repeat:true;triggeredOnStart:true;onTriggered:w.clock=new Date()}
 onMoonStateChanged:if(visible&&lunarScene)requestPaint()
 onSkyChanged:{phase=0;requestPaint()}
 onAmbientChanged:requestPaint()
 onArtworkChanged:requestPaint()
 function wrap(n,size){return ((n%size)+size)%size}
 function glow(c,x,y,r,inner,outer,alpha){
  var g=c.createRadialGradient(x,y,0,x,y,r);g.addColorStop(0,inner);g.addColorStop(1,outer)
  c.globalAlpha=alpha;c.fillStyle=g;c.fillRect(0,0,720,720)
 }
 function mist(c,y,offset,tint,alpha,scaleY){
  c.save();c.translate(360+offset,y);c.scale(1,scaleY)
  var g=c.createRadialGradient(0,0,15,0,0,580);g.addColorStop(0,tint);g.addColorStop(1,'rgba(180,195,198,0)')
  c.fillStyle=g;c.globalAlpha=alpha;c.fillRect(-620,-620,1240,1240);c.restore()
 }
 function moon(c,strength){
  glow(c,618,74,215,'rgba(169,196,216,.18)','rgba(169,196,216,0)',strength*(.10+.90*Math.sqrt(moonState.illumination)))
  Lunar.draw(c,618,74,43,moonState,strength)
 }
 function ribbons(c,tint,alpha,speed){
  for(var k=0;k<5;k++){
   var x=wrap(k*239+phase*(speed+k*2),1240)-260,y=60+k*151+Math.sin(phase*.38+k)*18
   var g=c.createLinearGradient(x,0,x+370,0);g.addColorStop(0,'rgba('+tint+',0)');g.addColorStop(.45,'rgba('+tint+','+alpha+')');g.addColorStop(1,'rgba('+tint+',0)')
   c.fillStyle=g;c.beginPath();c.moveTo(x,y);c.bezierCurveTo(x+100,y-40,x+230,y+39,x+370,y-8);c.lineTo(x+370,y+24);c.bezierCurveTo(x+225,y+60,x+110,y-12,x,y+28);c.closePath();c.fill()
  }
 }
 onPaint:{
  var begin=Date.now(),c=getContext('2d');c.clearRect(0,0,width,height);if(scene==='none')return
  var palettes={sun:['#514331','#172122'],night:['#13233a','#0b111c'],rain:['#182c3c','#293b43'],snow:['#263d4c','#405963'],wind:['#263d42','#15282e'],dust:['#574638','#292b29'],haze:['#414643','#252f32'],fog:['#3d5158','#26363e'],cloud:['#2c414c','#172933']}
  var colors=scene==='cloud'&&night?palettes.night:palettes[scene],g=c.createLinearGradient(0,0,170,720)
  g.addColorStop(0,colors[0]);g.addColorStop(1,colors[1]);c.fillStyle=g
  if(!(ambient&&artwork)){c.globalAlpha=1;c.fillRect(0,0,720,720)}
  var strength=ambient&&artwork?.78:1
  if(scene==='sun'){
   // Broad daylight field and gently shifting shafts, with no corner clipping.
   glow(c,515+Math.sin(phase*.25)*65,-85,920,'rgba(255,221,151,0.58)','rgba(243,191,102,0)',(.82+.12*Math.sin(phase*.75))*strength)
   glow(c,25,520,620,'rgba(171,185,167,0.12)','rgba(171,185,167,0)',strength)
   c.save();c.translate(545,-220);c.rotate(-.32+Math.sin(phase*.35)*.09)
   for(var b=0;b<3;b++){
    c.save();c.translate(-190+b*185,350);c.scale(.42,3.4)
    var beam=c.createRadialGradient(0,0,0,0,0,270);beam.addColorStop(0,'rgba(255,230,166,0.10)');beam.addColorStop(1,'rgba(255,230,166,0)')
    c.fillStyle=beam;c.globalAlpha=strength;c.fillRect(-280,-280,560,560);c.restore()
   }c.restore()
   // A generous cropped solar disc gives the broad lighting a visible origin.
   var sunX=704,sunY=40,sunR=120
   glow(c,sunX,sunY,340,'rgba(255,218,133,0.55)','rgba(255,218,133,0)',.8*strength)
   var disc=c.createRadialGradient(sunX-20,sunY+12,2,sunX,sunY,sunR)
   disc.addColorStop(0,'#fff8d9');disc.addColorStop(.82,'#ffe9a7');disc.addColorStop(1,'#eec574')
   c.globalAlpha=.94*strength;c.fillStyle=disc;c.beginPath();c.arc(sunX,sunY,sunR,0,Math.PI*2);c.fill()
   c.save();c.translate(sunX,sunY);c.rotate(phase*.13);c.strokeStyle='#ffe7a0';c.lineWidth=3;c.globalAlpha=.26*strength
   for(var ray=0;ray<12;ray++){c.rotate(Math.PI/6);c.beginPath();c.moveTo(138,0);c.lineTo(160+Math.sin(phase*.8+ray)*9,0);c.stroke()}c.restore()
  }else if(scene==='night'){
   glow(c,535,30,790,'rgba(135,172,205,0.34)','rgba(119,153,191,0)',strength)
   moon(c,strength)
   for(var n=0;n<42;n++){var sx=wrap(n*137.73+21,720),sy=wrap(n*93.3+34,650);c.fillStyle='#d6e6e8';c.globalAlpha=(.25+.32*(1+Math.sin(phase*1.15+n))*.5)*strength;c.beginPath();c.arc(sx,sy,n%7===0?2.1:1.2,0,Math.PI*2);c.fill();if(n%7===0){c.strokeStyle='#d6e6e8';c.lineWidth=1;c.beginPath();c.moveTo(sx-4,sy);c.lineTo(sx+4,sy);c.moveTo(sx,sy-4);c.lineTo(sx,sy+4);c.stroke()}}
  }else if(scene==='cloud'){
   if(night){
    moon(c,.77*strength)
    // A cloud veil crosses the lower lit limb, sharing the same drifting sky.
    var veilX=655+Math.sin(phase*.24)*65,veilY=112
    var veil=c.createRadialGradient(veilX,veilY,8,veilX,veilY,150)
    veil.addColorStop(0,'rgba(113,137,153,.56)');veil.addColorStop(.56,'rgba(99,126,146,.28)');veil.addColorStop(1,'rgba(87,116,138,0)')
    c.fillStyle=veil;c.globalAlpha=strength;c.fillRect(veilX-150,veilY-150,300,300)
   }
   if(!night&&!overcast)glow(c,682,8,260,'rgba(255,228,160,.55)','rgba(255,228,160,0)',strength)
   glow(c,520,110,620,'rgba(225,232,212,0.22)','rgba(225,232,212,0)',strength)
   for(var row=0;row<4;row++){
    var x=wrap(row*291+phase*(row%2?22:-17),1120)-230,y=92+row*155+Math.sin(phase*.35+row)*22;
    for(var lobe=0;lobe<3;lobe++){
     var xx=x+lobe*95,yy=y+(lobe===1?-28:16),r=152-lobe*12,cloud=c.createRadialGradient(xx,yy,12,xx,yy,r);
     cloud.addColorStop(0,'rgba(215,229,225,0.38)');cloud.addColorStop(.52,'rgba(180,203,205,0.23)');cloud.addColorStop(1,'rgba(160,186,193,0)');c.globalAlpha=(overcast?1.15:night?.74:1)*strength;c.fillStyle=cloud;c.fillRect(xx-r,yy-r,r*2,r*2)
    }
   }
  }else if(scene==='rain'||scene==='snow'){
   // Static backdrop; the foreground particle layer owns motion and collisions.
   mist(c,90,0,'#9bb4bd',.14*strength,.32)
   if(scene==='snow')mist(c,695,0,'#bad2dc',.15*strength,.23)
   if(thunder){
    // Local lightning is readable without flashing the entire screen or text.
    var pulse=wrap(phase,7.4),flash=pulse<.22?1-pulse/.22:pulse>.38&&pulse<.58?.55*(1-(pulse-.38)/.2):.12
    c.strokeStyle='#e2e8dd';c.lineWidth=4;c.lineJoin='bevel';c.globalAlpha=flash*strength;c.beginPath();c.moveTo(598,28);c.lineTo(551,106);c.lineTo(589,100);c.lineTo(535,185);c.stroke()
   }
  }else if(scene==='wind'){
   for(var r=0;r<9;r++){
    var x=wrap(r*181+phase*(43+r*2),1150)-360,y=65+r*77+Math.sin(phase*.25+r)*18
    var ribbon=c.createLinearGradient(x,0,x+280,0);ribbon.addColorStop(0,'rgba(198,220,217,0)');ribbon.addColorStop(.5,'rgba(198,220,217,0.38)');ribbon.addColorStop(1,'rgba(198,220,217,0)')
    c.strokeStyle=ribbon;c.lineWidth=r%3===0?2.8:1.5;c.globalAlpha=strength;c.beginPath();c.moveTo(x,y);c.bezierCurveTo(x+80,y-26,x+185,y+24,x+280,y-7);c.stroke()
   }
   mist(c,210,Math.sin(phase*.15)*180,'#a6c6c4',.10*strength,.24);mist(c,560,Math.cos(phase*.12)*150,'#8dadb8',.09*strength,.3)
  }else{
   var dust=scene==='dust',haze=scene==='haze',fog=scene==='fog',tint=dust?'#d6b17c':haze?'#b8b8a2':'#b5c7cb'
   for(var m=0;m<5;m++)mist(c,70+m*156,Math.sin(phase*(dust?.28:haze?.18:.24)+m*1.7)*180,tint,(dust?.16:haze?.14:.18)*strength,.22+m%2*.08)
   c.globalAlpha=strength
   if(fog)ribbons(c,'195,216,218',.15,24)
   if(haze)ribbons(c,'195,193,159',.095,12)
   if(dust||haze){for(var p=0;p<(dust?78:38);p++){var px=wrap(p*137+phase*(dust?48+p%4*13:13+p%4*3),790)-35,py=wrap(p*91+Math.sin(phase*.6+p)*16,750)-15;c.globalAlpha=(dust?.17+p%4*.055:.13+p%3*.035)*strength;c.fillStyle=dust?'#e6cb98':'#c5c4a6';c.beginPath();c.arc(px,py,(dust?1: .7)+p%3*.55,0,Math.PI*2);c.fill();if(dust&&p%5===0){c.lineWidth=1;c.strokeStyle='#e6cb98';c.beginPath();c.moveTo(px-7,py+2);c.lineTo(px,py);c.stroke()}}}
  }
  // Shading belongs to the background; foreground text is never dimmed.
  var shade=c.createLinearGradient(0,290,0,720);shade.addColorStop(0,'rgba(3,9,12,0)');shade.addColorStop(1,'rgba(3,9,12,0.26)');if(!(ambient&&artwork)){c.globalAlpha=1;c.fillStyle=shade;c.fillRect(0,0,720,720)}
  c.globalAlpha=1;probe.recordJs(Date.now()-begin)
 }
}
