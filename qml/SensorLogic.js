.pragma library
// Preserve physical positions: replacing the primary changes one default slot.
function secondaryKeys(primary) {
 var slots=["airCO2","airTVOC","airPM10","airTEMP","airHUMI","airNoise"]
 var i=slots.indexOf(primary)
 if(i>=0)slots[i]="airPM25"
 return slots
}
// These are the device's configured categories, never a percentage or a new standard.
function gradeIndex(sensor, preparingState) {
 if(!sensor || sensor.state===preparingState)return -1
 var list=sensor.evalutionDataList||[]
 for(var i=0;i<list.length;i++)if(String(list[i].description).trim()===String(sensor.evalutionDescription).trim())return i
 return -1
}
function kind(key) {
 if(key==="airTEMP"||key==="airHUMI")return "comfort"
 if(key==="airNoise")return "sound"
 return "air"
}

function categories(sensor) {
 var source=sensor?(sensor.evalutionDataList||[]):[], result=[]
 for(var i=0;i<source.length;i++)result.push({label:String(source[i].description),tint:String(source[i].color)})
 return result
}
