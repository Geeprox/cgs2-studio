.pragma library
function interval(value){var n=Number(value);return isFinite(n)?Math.max(3000,Math.min(60000,Math.round(n))):10000}
function target(media,current,direction,automatic){
 if(automatic&&media&&media.mediaKind==='photo'){
  if(!nextPreview(media,current))return null;
  if(Number(media.nextIndex)>=0)return {page:Number(media.nextPage)||0,index:Number(media.nextIndex)};
  if(Number(media.nextPage)!==(Number(media.offset)||0))return {page:Number(media.nextPage)||0,index:0};
  return null;
 }
 var items=media&&media.items||[],offset=Number(media&&media.offset)||0,n=items.length;
 if(!n)return null;
 var next=current+(direction<0?-1:1);
 if(next<0)return offset>0&&media.hasPrevious!==false?{page:Math.max(0,offset-24),index:23}:null;
 if(next<n)return {page:offset,index:next};
 if(media.hasMore===true)return {page:offset+24,index:0};
 return automatic?{page:0,index:0}:null;
}
function accept(value,requestId,lastStamp){
 if(!value||value.protocol!==2||!Array.isArray(value.items)||value.items.length>24)return false;
 if(requestId!==''&&value.requestId!==requestId)return false;
 return isFinite(Number(value.stateUptimeMs))&&Number(value.stateUptimeMs)>=lastStamp;
}
function selected(media,current){return media&&media.items&&current>=0&&current<media.items.length?media.items[current]:null}
function readyPhoto(item){return !!item&&item.previewReady===true&&typeof item.preview==='string'&&item.preview.indexOf('file:///tmp/cgs2-media/cache/')===0}
function readyVideo(media,item){return !!item&&(item.kind==='video'||item.kind==='audio'||item.live===true)&&(String(media.readyVideoId)===String(item.id)||item.live===true&&item.liveReady===true)&&typeof item.playback==='string'&&(item.playback.indexOf('file:///userdata/cgs2-ui/cache/media/')===0||/^http:\/\/127\.0\.0\.1:6097\/media\/[0-9]{1,12}\?revision=[a-f0-9]{24}$/.test(item.playback))}

// Only warm a published, local preview; the client publishes after atomic rename.
function nextPreview(media,current){
 if(media&&media.mediaKind==='photo')return readyPhoto({previewReady:true,preview:media.nextPreview})?media.nextPreview:'';
 var next=target(media,current,1,true);
 if(!next||next.page!==(Number(media&&media.offset)||0))return '';
 var item=selected(media,next.index);return readyPhoto(item)?item.preview:'';
}

function motionPlan(iw,ih,w,h,seed,duration,intro){
 var state=(seed>>>0)||1;function rand(){state=(1664525*state+1013904223)>>>0;return state/4294967296}
 var ratio=iw/Math.max(1,ih),wide=ratio>w/h*1.15,vertical=ratio<w/h*.85;
 var z0=intro?1:1.06+rand()*.08,z1=1.17+rand()*.08;
 if(!intro&&rand()<.45){var swap=z0;z0=z1;z1=swap}
 var bw=Math.max(w,h*ratio),bh=Math.max(h,w/Math.max(.01,ratio));
 var mx=Math.max(0,(bw*Math.min(z0,z1)-w)/2),my=Math.max(0,(bh*Math.min(z0,z1)-h)/2);
 var horizontal=wide?rand()<.85:vertical?rand()<.2:rand()<.5;
 var seconds=Math.max(3,duration/1000),ax=Math.min(mx*.75,seconds*28),ay=Math.min(my*.75,seconds*24),dir=rand()<.5?-1:1;
 if(horizontal)ay*=.22;else ax*=.22;
 return {z0:z0,z1:z1,x0:intro?0:-dir*ax,x1:dir*ax,y0:intro?0:dir*ay,y1:-dir*ay,horizontal:horizontal,wide:wide};
}
