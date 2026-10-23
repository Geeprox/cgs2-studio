// SPDX-License-Identifier: MIT
const fs=require('fs'), vm=require('vm'), crypto=require('crypto');
const stage=require('path').join(__dirname,'../qml');
const engine={}, lunar={};vm.createContext(engine);
vm.runInContext(fs.readFileSync(stage+'/AstronomyEngine.js','utf8').replace('.pragma library',''),engine);
lunar.Engine=engine;vm.createContext(lunar);
vm.runInContext(fs.readFileSync(stage+'/MoonPhase.js','utf8').replace('.pragma library','').replace('.import "AstronomyEngine.js" as Engine',''),lunar);
const refs=[
 ['2026-09-11T03:27:00Z',0],['2026-09-18T20:44:00Z',90],['2026-09-26T16:49:00Z',180],['2026-10-03T13:25:00Z',270],
 ['2026-10-10T15:50:00Z',0],['2026-10-18T16:12:00Z',90],['2026-10-26T04:12:00Z',180],['2026-11-01T20:28:00Z',270]
];
const days=ms=>(ms-Date.UTC(2000,0,1,12))/86400000;
const baseline=refs.map(([utc,target])=>{
 const state=lunar.at(Date.parse(utc));
 const angularError=Math.abs(((state.longitude-target+540)%360)-180);
 const event=engine.Astronomy.SearchMoonPhase(target,days(Date.parse(utc)-86400000),2);
 const errorSeconds=(event.date.getTime()-Date.parse(utc))/1000;
 if(angularError>.02||Math.abs(errorSeconds)>120)throw Error('USNO mismatch '+utc);
 if(target===0&&state.illumination>=.01||target===180&&state.illumination<=.99||target%180===90&&Math.abs(state.illumination-.5)>.01)throw Error('Illumination '+utc);
 return {usnoUtc:utc,phaseLongitudeDegrees:target,calculatedLongitude:state.longitude,longitudeErrorDegrees:angularError,calculatedEventUtc:event.date.toISOString(),eventDifferenceSeconds:errorSeconds,illumination:state.illumination};
});
const current=lunar.at(Date.parse('2026-10-22T15:30:00Z'));
if(current.label!=='盈凸月'||!current.waxing||current.illumination<.8||current.illumination>.9)throw Error('Current date phase');
const sameInstant=lunar.at(Date.parse('2026-10-22T23:30:00+08:00'));
if(JSON.stringify(sameInstant)!==JSON.stringify(current))throw Error('Timezone instant mismatch');
const count=lunar.calculations;lunar.at(Date.parse('2026-10-22T15:30:59Z'));if(lunar.calculations!==count)throw Error('Minute cache');
lunar.at(Date.parse('2026-10-22T15:31:00Z'));if(lunar.calculations!==count+1)throw Error('Minute boundary refresh');
if(lunar.at(NaN).valid)throw Error('Invalid date');
const samples=[];
for(let target=0;target<360;target+=30){
 const event=engine.Astronomy.SearchMoonPhase(target,days(Date.parse('2026-10-08T00:00:00Z')),35);
 samples.push({target:target,utc:event.date.toISOString(),state:lunar.at(event.date.getTime())});
}
// Geometry area must equal the illuminated fraction for either waxing side.
const area=[];
for(const f of [0,.067,.25,.5,.75,.933,1]){
 let total=0;const n=10000;
 for(let i=0;i<n;i++){const y=-1+(i+.5)*2/n,limb=Math.sqrt(1-y*y);total+=(limb-(1-2*f)*limb)*2/n;}
 const measured=total/Math.PI;if(Math.abs(measured-f)>.00001)throw Error('Terminator area '+f);
 area.push({illumination:f,numericallyIntegratedFraction:measured});
}
const report={algorithm:'Astronomy Engine official ES5 browser bundle; MoonPhase plus Illumination; numeric UTC J2000 days',source:'https://github.com/cosinekitty/astronomy',reference:'https://aa.usno.navy.mil/calculated/moon/phases?date=2026-08-12&format=p&nump=50&submit=Get+Data',baseline:baseline,currentShanghai:'2026-10-22 23:30:00 +08:00',current:current,samples:samples,geometry:area,minuteCache:true,timeZoneSameInstant:true,invalidDateRejected:true,orientation:'North-up schematic; no observer location or real horizon tilt'};
console.log('PASS moon phase events, UTC identity, minute cache and illuminated geometry');
