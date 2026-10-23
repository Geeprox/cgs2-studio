.pragma library
.import "AstronomyEngine.js" as Engine

// Geocentric ephemeris and illuminated fraction, calculated locally. Time is
// UTC internally; a Date preserves the same instant in every system timezone.
// Orientation is a north-up schematic: waxing right, waning left. No observer
// location, parallactic angle, libration, horizon or eclipse prediction is used.
var cachedMinute = NaN
var cachedResult = null
var calculations = 0
function at(date){
 var ms=typeof date==='number'?date:date&&date.getTime?date.getTime():NaN
 if(!isFinite(ms))return {valid:false,illumination:0,waxing:true,longitude:0,label:''}
 var minute=Math.floor(ms/60000)
 if(cachedResult&&minute===cachedMinute)return cachedResult
 var instant=new Date(minute*60000)
 // Numeric UTC days avoid cross-module Date-constructor identity assumptions.
 var utcDays=(instant.getTime()-Date.UTC(2000,0,1,12))/86400000
 var longitude=Engine.Astronomy.MoonPhase(utcDays)
 var light=Engine.Astronomy.Illumination(Engine.Astronomy.Body.Moon,utcDays)
 var fraction=Math.max(0,Math.min(1,light.phase_fraction)),waxing=longitude<180
 var label=fraction<.012?'新月':fraction>.988?'满月':Math.abs(fraction-.5)<.025?(waxing?'上弦月':'下弦月'):fraction<.5?(waxing?'娥眉月':'残月'):(waxing?'盈凸月':'亏凸月')
 cachedMinute=minute;calculations++
 cachedResult={valid:true,minute:minute,utc:instant.toISOString(),longitude:longitude,phaseAngle:light.phase_angle,illumination:fraction,waxing:waxing,label:label}
 return cachedResult
}
function outline(c,r,fraction){
 // A half ellipse is the projection of the spherical light terminator. Its
 // signed width passes continuously through new, half, full and back again.
 var k=.5522847498307936,term=(1-2*fraction)*r
 c.beginPath();c.moveTo(0,-r)
 c.bezierCurveTo(r*k,-r,r,-r*k,r,0);c.bezierCurveTo(r,r*k,r*k,r,0,r)
 c.bezierCurveTo(term*k,r,term,r*k,term,0);c.bezierCurveTo(term,-r*k,term*k,-r,0,-r)
 c.closePath()
}
function draw(c,x,y,r,state,strength){
 if(!state||!state.valid)return
 var f=state.illumination
 c.save();c.translate(x,y)
 // Earthshine is deliberately faint. At new moon this is a dim local sphere,
 // never an artificially illuminated full disc.
 c.globalAlpha=.14*strength;c.fillStyle='#71818c';c.beginPath();c.arc(0,0,r,0,Math.PI*2);c.fill()
 if(f>.00001){
  c.scale(state.waxing?1:-1,1)
  var face=c.createLinearGradient(-r,-r*.2,r,r*.1)
  face.addColorStop(0,'#a6b7c2');face.addColorStop(.58,'#d0d9da');face.addColorStop(1,'#e1e7e4')
  outline(c,r,f);c.globalAlpha=.90*strength;c.fillStyle=face;c.fill();c.clip()
  var spots=[[-12,-14,15],[18,-18,11],[24,8,14],[-9,23,10],[6,4,9]]
  for(var j=0;j<spots.length;j++){var p=spots[j],g=c.createRadialGradient(p[0],p[1],0,p[0],p[1],p[2]);g.addColorStop(0,'rgba(83,111,130,.20)');g.addColorStop(1,'rgba(83,111,130,0)');c.fillStyle=g;c.fillRect(p[0]-p[2],p[1]-p[2],p[2]*2,p[2]*2)}
 }
 c.restore()
}
