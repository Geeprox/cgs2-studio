import QtQuick 2.9
Item{
 id:p
 property bool enabled:false
 property string sourceName:''
 property var sampleState:({start:0,count:0,last:0,gaps:[],costs:[]})
 signal sample(var metrics)
 function reset(){sampleState={start:Date.now(),count:0,last:0,gaps:[],costs:[]}}
 function recordJs(ms){if(enabled&&sampleState.costs.length<256)sampleState.costs.push(ms)}
 function painted(){if(!enabled)return;var s=sampleState,t=Date.now();s.count++;if(s.last&&s.gaps.length<256)s.gaps.push(t-s.last);s.last=t}
 function percentile(a,q){if(!a.length)return 0;var b=a.slice().sort(function(x,y){return x-y});return b[Math.min(b.length-1,Math.floor(b.length*q))]}
 onEnabledChanged:reset()
 Timer{interval:5000;running:p.enabled;repeat:true;onTriggered:{
  var s=p.sampleState,elapsed=Date.now()-s.start
  if(elapsed>0&&elapsed<15000)p.sample({source:p.sourceName,elapsedMs:elapsed,canvasPaints:s.count,canvasPaintFps:s.count*1000/elapsed,p95JsIssueMs:p.percentile(s.costs,.95),p95PaintIntervalMs:p.percentile(s.gaps,.95)})
  p.reset()
 }}
}
