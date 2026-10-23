.pragma library
var names=['Ultra Modular','Air Wayfinder','Infograph','双模块','XL Air','空间透视','Chrono','俯视泳池','天气剧场','涂鸦气象','流光仪表','构成·空气','星际观测','声笺'];
var slots=['airCO2','airTVOC','airNoise','airTEMP','airHUMI','airPM10'];
function secondary(primary,skin){var a=slots.slice();var n=a.indexOf(primary);if(n>=0)a[n]='airPM25';if(skin===3){var s=primary==='airCO2'?'airPM25':'airCO2';a=a.filter(function(k){return k!==s})}return a}
function tint(k){return {airPM25:'#b7ed4c',airPM10:'#b7ed4c',airCO2:'#e3e763',airTVOC:'#c1a2f5',airNoise:'#ff954e',airTEMP:'#68cee7',airHUMI:'#719cf2'}[k]||'#b7ed4c'}
function label(k){return {airPM25:'PM2.5',airPM10:'PM10',airCO2:'<html>CO<sub>2</sub></html>',airTVOC:'eTVOC',airNoise:'噪声',airTEMP:'温度',airHUMI:'湿度'}[k]||k}
// Explicit display ranges; the text classification always comes from native firmware.
function range(k,s){if(k==='airTVOC'&&s&&String(s.unitString).indexOf('VOC')>=0)return [0,500];return {airPM25:[0,75],airPM10:[0,150],airCO2:[400,2000],airTVOC:[0,1],airNoise:[20,100],airTEMP:[-10,40],airHUMI:[0,100]}[k]||[0,100]}
function ratio(k,s){var r=range(k,s),v=Number(s?s.valueString:0);return isFinite(v)?Math.max(0,Math.min(1,(v-r[0])/(r[1]-r[0]))):0}
function pos(s,i){var p={0:[[96,98],[296,98],[496,98],[96,506],[296,506],[496,506]],1:[[84,132],[499,132],[52,326],[531,326],[151,524],[432,524]],2:[[96,132],[496,132],[60,326],[532,326],[144,520],[448,520]],3:[[96,548],[204,548],[312,548],[420,548],[528,548]],4:[[96,430],[296,430],[496,430],[96,548],[296,548],[496,548]],6:[[96,98],[296,98],[496,98],[96,520],[296,520],[496,520]],7:[[102,350],[388,350],[102,454],[388,454],[102,558],[388,558]]};return (p[s]||p[0])[i]}

function minimumSpan(k,s){return {airPM25:10,airPM10:20,airCO2:200,airTVOC:String(s&&s.unitString).indexOf('VOC')>=0?50:.2,airNoise:15,airTEMP:4,airHUMI:20}[k]||10}

function rimPoint(f){
 var R=110,L=452,A=Math.PI*R/2,total=4*L+4*A,s=((f%1+1)%1)*total+L/2;s=s%total
 var seg=[L,A,L,A,L,A,L,A],x=134,y=24;
 for(var i=0;i<8;i++){if(s<=seg[i]){if(i===0)return [134+s,24];if(i===1){var a=-Math.PI/2+s/R;return [586+R*Math.cos(a),134+R*Math.sin(a)]}if(i===2)return [696,134+s];if(i===3){var a=s/R;return [586+R*Math.cos(a),586+R*Math.sin(a)]}if(i===4)return [586-s,696];if(i===5){var a=Math.PI/2+s/R;return [134+R*Math.cos(a),586+R*Math.sin(a)]}if(i===6)return [24,586-s];var a=Math.PI+s/R;return [134+R*Math.cos(a),134+R*Math.sin(a)]}s-=seg[i]}return [360,24]
}

function weatherSurfaces(s){
 var a=[],circle=function(x,y,r){a.push({type:'circle',cx:x,cy:y,r:r})},rect=function(x,y,w,h,r){a.push({type:'rect',x:x,y:y,w:w,h:h,radius:r})}
 if(s===0||s===1||s===2||s===6){
  for(var i=0;i<6;i++){var p=pos(s,i),w=s===1?137:128;circle(p[0]+w/2,p[1]+w/2,w*.465)}
  if(s===1)circle(360,355,153);if(s===2){circle(360,327,153);circle(360,584,64)}if(s===6)circle(216,370,112)
  if(s===0)rect(96,489,528,0,0)
 }else if(s===3){rect(96,222,528,140,25);rect(96,382,528,140,25)}
 else if(s===5)circle(360,245,168)
 else if(s===7){circle(321.12,216.2,128.16);circle(394.56,241.4,119.52);circle(355.68,291.8,108.72)}
 if(s===5||s===7||s>=8)rect(68,s===9||s===11?402:478,584,s===9||s===11?250:174,25)
 return a
}
function weatherExclusions(s){
 var a=[[110,36,500,62],[128,646,468,62]]
 if(s===0)a.push([95,250,530,132],[96,390,528,95]);if(s===1)a.push([275,55,175,95]);if(s===2)a.push([230,78,260,55]);if(s===3)a.push([95,79,530,132]);if(s===4)a.push([420,78,205,88],[95,126,530,295],[80,425,560,220]);if(s===6)a.push([355,250,278,224]);if(s>=8)a.push([80,s===8?190:90,550,125],[100,370,520,105]);return a
}

// Clockwise tangent gives the same inward direction for ticks and the seconds hand.
function rimMark(t,length){var p=rimPoint(t),a=rimPoint(t-.00001),b=rimPoint(t+.00001),dx=b[0]-a[0],dy=b[1]-a[1],n=Math.sqrt(dx*dx+dy*dy);return [p[0],p[1],p[0]-dy/n*length,p[1]+dx/n*length]}

// Each face owns one seconds display. Spatial skin 12 is a preview-only replacement.
function secondsMode(s,spatialPreview){
 if(s===100)return 'native';
 if(s===2||s===6)return 'analogue';
 if(s===3||s===5||s===8||s===9||s===13||s===12&&!spatialPreview)return 'digital';
 if(s===0||s===1)return 'rim';
 return 'none';
}
function timeFormat(s){return s===3||s===8||s===9||s===12?'HH:mm:ss':'HH:mm'}
function showsOuterScale(s){return s===0||s===1||s===2||s===6}
function supportsWeather(s){return s!==5&&s!==12&&s!==13}
function usesArtFace(s,spatialPreview){return [5,7,9,10,11].indexOf(s)>=0||s===12&&spatialPreview}

function navigationInk(s){return s===9||s===11||s===13?'#405544':s===7?'#f2fff7':'#b7c7a6'}

function trendAxis(samples){
 if(!samples||samples.length<2)return '积累历史中';
 var first=new Date(samples[0][0]*1000),last=new Date(samples[samples.length-1][0]*1000),crossDay=first.getFullYear()!==last.getFullYear()||first.getMonth()!==last.getMonth()||first.getDate()!==last.getDate(),format=crossDay?'MM.dd HH:mm':'HH:mm';
 return Qt.formatDateTime(first,format)+' — '+Qt.formatDateTime(last,format);
}
