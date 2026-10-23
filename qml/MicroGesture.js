.pragma library
function axis(dx,dy,current){if(current)return current;return Math.max(Math.abs(dx),Math.abs(dy))>16?(Math.abs(dx)>=Math.abs(dy)?'x':'y'):''}
function vector(dx,dy){var x=dx/3,y=dy/3,n=Math.max(1,Math.sqrt(x*x+y*y)/14);return {x:x/n,y:y/n}}
function direction(dx,dy,lockedAxis){
 var a=lockedAxis||axis(dx,dy,'');
 if(a==='x'&&Math.abs(dx)>16)return dx>0?'stickRight':'stickLeft';
 if(a==='y'&&Math.abs(dy)>16)return dy>0?'stickDown':'stickUp';
 return '';
}
