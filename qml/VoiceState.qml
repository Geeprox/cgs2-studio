import QtQuick 2.9
Item {
 id:s;objectName:'voice-state'
 property var store:null
 property bool active:false
 property string ipcRoot:'file:///tmp/cgs2-voice/'
 property string status:'idle'
 property string text:''
 property string partial:''
 property string error:''
 property real level:0
 property string session:''
 property bool requested:false
 property int elapsed:0
 readonly property bool busy:requested||status==='transcribing'
 readonly property string displayText:text+(partial!==''?(text!==''?'\n':'')+partial:'')
 function request(action){
  if(!store||!store.write||!(store.uptime>0))return '';
  var id=String(Date.now())+'-'+Math.floor(Math.random()*1000000000);
  if(!store.write(ipcRoot+'request.json',{id:id,action:action,session:action==='start'?id:session,uptime:store.uptime}))return '';
  return id;
 }
 function start(){
  if(!active||busy)return;
  var id=request('start');if(id===''){status='error';return}
  session=id;requested=true;elapsed=0;text='';partial='';error='';level=0;status='starting';
 }
 function stop(){
  if(requested){request('stop');requested=false;if(status==='listening'||status==='starting')status='transcribing'}
  level=0;
 }
 function accept(value){
  if(!value)return;
  var next=String(value.status||'');if(['idle','starting','listening','transcribing','done','error'].indexOf(next)<0)return;
  // A recreated face may still have a bounded tail in flight. Adopt the
  // latest valid private IPC session only while active, without owning or
  // restarting its capture. Once adopted, keep the usual strict session fence.
  if(session===''){
   if(!active||requested||typeof value.session!=='string'||!/^[A-Za-z0-9_-]{1,80}$/.test(value.session))return;
   session=value.session;
  }
  if(String(value.session)!==session)return;
  text=typeof value.text==='string'?value.text.slice(-1200):'';
  partial=typeof value.partial==='string'?value.partial.slice(-1200):'';
  error=typeof value.error==='string'?value.error:'';
  var n=Number(value.level);level=isFinite(n)?Math.max(0,Math.min(1,n)):0;
  status=(next==='listening'||next==='starting')&&!requested?'transcribing':next;
  if(next==='done'||next==='idle'||next==='error'){requested=false;level=0}
 }
 function poll(){if(active&&store&&store.read)store.read(ipcRoot+'state.json',function(v){s.accept(v)})}
 onActiveChanged:{if(!active)stop();else poll()}
 Timer{interval:s.busy?200:1000;running:s.active;repeat:true;triggeredOnStart:true;onTriggered:s.poll()}
 Timer{interval:2000;running:s.active&&s.requested&&(s.status==='listening'||s.status==='transcribing');repeat:true;onTriggered:if(s.requested)s.request('keepalive')}
 Timer{interval:1000;running:s.requested;repeat:true;onTriggered:{s.elapsed++;if(s.elapsed>=20)s.stop();else if(s.elapsed>=8&&s.status==='starting'){s.stop();s.status='error'}}}
 Component.onDestruction:stop()
}
