import QtQuick 2.9
import 'WeatherPhysics.js' as Physics
import 'WeatherSky.js' as Sky
Canvas{
 id:w
 property string sky:''
 property var surfaces:[]
 property var exclusions:[]
 property bool running:true
 property bool diagnostics:false
 readonly property string kind:Sky.precipitation(sky)
 property var world:Physics.create(kind,surfaces,48973)
 property real lastMs:0
 signal benchmark(var metrics)
 function reset(){world=Physics.create(kind,surfaces,48973);lastMs=0;requestPaint()}
 onKindChanged:reset()
 onSurfacesChanged:reset()
 onRunningChanged:lastMs=0
 onAvailableChanged:if(available)requestPaint()
 onVisibleChanged:if(visible){lastMs=0;requestPaint()}
 PaintProbe{id:probe;enabled:w.diagnostics&&w.running&&w.visible&&w.kind!=='';sourceName:'weather-particles';onSample:{metrics.kind=w.kind;metrics.physics=Physics.summary(w.world);w.benchmark(metrics)}}
 Timer{interval:50;running:w.running&&w.visible&&w.kind!=='';repeat:true;onTriggered:{var t=Date.now(),dt=w.lastMs?(t-w.lastMs)/1000:.05;w.lastMs=t;Physics.step(w.world,dt);w.requestPaint()}}
 onPaint:{var begin=Date.now(),c=getContext('2d');c.clearRect(0,0,width,height);if(kind!=='')Physics.draw(c,world,exclusions);for(var i=0;i<exclusions.length;i++){var b=exclusions[i];c.clearRect(b[0],b[1],b[2],b[3])}probe.recordJs(Date.now()-begin)}
 onPainted:probe.painted()
}
