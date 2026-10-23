import QtQuick 2.9
import QtMultimedia 5.12
import 'MediaLogic.js' as Logic
Rectangle {
 id:p;objectName:'media-panel';color:'#070c0c';property var store;property color accent:'#d3ad7a';signal closed()
 property string mediaKind:'photo'
 readonly property string pageTitle:mediaKind==='video'?'视频播放':mediaKind==='audio'?'音乐播放':'相册'
 property var media:({enabled:false,items:[]})
 property int current:0
 property bool slideshow:false
 property bool controls:true
 property bool fillPhotos:true
 property bool clearingVideo:false
 property bool accepting:false
 property int liveCompletedCount:0
 property bool liveStarted:false
 property bool livePlayback:false
 property bool liveAdvance:false
 property string liveHandled:''
 readonly property string selectionKey:String(media.revision||'')+':'+(selected?String(selected.id):'')
 property bool soundEnabled:mediaKind==='audio'
 property bool videoPending:false
 property string videoItem:''
 property string preparedUrl:''
 property string photoSource:''
 property string requestId:''
 property int requestAt:0
 property int requestNumber:0
 property real lastStamp:0
 property string feedbackText:''
 readonly property bool active:visible&&(!store||store.displayAwake)
 readonly property var selected:Logic.selected(media,current)
 readonly property bool photoReady:Logic.readyPhoto(selected)&&String(photo.displayedSource)===String(selected.preview)&&!photo.failed
 readonly property string nextPhoto:Logic.nextPreview(media,current)
 readonly property bool navigating:requestId!==''&&!videoPending
 readonly property bool videoShowing:player.playbackState!==MediaPlayer.StoppedState
 readonly property int videoPosition:player.position
 readonly property int videoState:player.playbackState
 readonly property int slideInterval:Logic.interval(media.intervalMs)
 function presence(on){if(store&&store.uptime>0)store.write('file:///tmp/cgs2-media/presence.json',{uptime:store.uptime,active:on})}
 function keepAwake(){if(active&&(!store||!store.nightWindowActive)&&typeof screenManager!=='undefined')screenManager.onInterfaceTouched()}
 function clearVideo(){clearingVideo=true;liveStarted=false;livePlayback=false;liveAdvance=false;videoPending=false;videoItem='';preparedUrl='';player.stop();player.source='';clearingVideo=false}
 function beginLive(){
  if(!active||!slideshow||!selected||selected.live!==true||videoPending||videoShowing||liveStarted||liveHandled===selectionKey)return;
  livePlayback=true;videoPending=true;videoItem=String(selected.id);preparedUrl='';
  if(Logic.readyVideo(media,selected))startPreparedVideo();else request(true);
 }
 function failedVideo(message){
  var wasLive=livePlayback;if(wasLive)liveHandled=selectionKey;
  clearVideo();requestId='';feedbackText=message;controls=true;
  if(wasLive&&active){request(false);syncSlide(true);}
 }
 function liveEnded(){
  if(!livePlayback||!liveStarted||!active||!selected||videoItem!==String(selected.id))return;
  liveCompletedCount++;liveHandled=selectionKey;clearVideo();liveAdvance=slideshow;
  syncSlide(false);
 }
 function syncSlide(restart){
  if(!slideTimer||clearingVideo||accepting)return;
  if(slideshow&&active&&photoReady&&!navigating){
   if(liveAdvance){slideTimer.stop();if(Logic.target(media,current,1,true)){liveAdvance=false;go(1,true)}return}
   if(selected&&selected.live===true&&liveHandled!==selectionKey){slideTimer.stop();beginLive();return}
   if(!videoPending&&!videoShowing){if(restart||!slideTimer.running)slideTimer.restart();return}
  }
  slideTimer.stop();
 }
 function request(video,page,index,force){
  if(!active||!store||store.uptime<=0)return false;
  requestId='media-'+Date.now()+'-'+(++requestNumber);requestAt=store.uptime;
  presence(true);
  return store.write('file:///tmp/cgs2-media/request.json',{protocol:2,kind:mediaKind,id:requestId,uptime:store.uptime,index:index===undefined?current:index,video:video===true,force:force===true,page:page===undefined?(media.offset||0):page})
 }
 function go(direction,automatic){
  if(!active||navigating||videoPending&&!livePlayback)return;
  var next=Logic.target(media,current,direction,automatic===true);if(!next)return;
  clearVideo();feedbackText='';slideTimer.stop();
  request(false,next.page,next.index);
  if(next.page===(media.offset||0)&&Logic.readyPhoto(media.items[next.index])){current=next.index;photoSource=String(selected.preview)}
 }
 function retry(){clearVideo();feedbackText='';photoSource='';request(false,undefined,undefined,true)}
 function startPreparedVideo(){
  if(!videoPending||!active||!selected||String(selected.id)!==videoItem||!Logic.readyVideo(media,selected)||preparedUrl!==''||livePlayback&&!slideshow)return;
  var url=String(selected.playback);preparedUrl=url;player.stop();player.source='';
  Qt.callLater(function(){if(p.active&&p.videoPending&&p.preparedUrl===url&&(!p.livePlayback||p.slideshow)){player.source=url;player.play()}})
 }
 function toggleVideo(){
  if(videoPending){clearVideo();request(false);return}
  if(player.playbackState===MediaPlayer.PlayingState){player.pause();controls=true;return}
  if(player.playbackState===MediaPlayer.PausedState){player.play();controls=false;return}
  if(!selected||selected.kind!=='video'&&selected.kind!=='audio')return;
  slideshow=false;feedbackText='';videoPending=true;videoItem=String(selected.id);preparedUrl='';
  if(Logic.readyVideo(media,selected))startPreparedVideo();else request(true);
 }
 function accept(v){
  if(!active||v.mediaKind!==mediaKind||!Logic.accept(v,requestId,lastStamp))return;
  accepting=true;lastStamp=Number(v.stateUptimeMs);
  var previousId=selected?String(selected.id):'',previousRevision=media.revision;
  media=v;current=Math.max(0,Math.min(Number(v.current)||0,v.items.length-1));
  if(!media.enabled||previousRevision&&previousRevision!==media.revision){photoSource='';clearVideo()}
  if(previousId&&selected&&previousId!==String(selected.id)){clearVideo();feedbackText=''}
  if(Logic.readyPhoto(selected))photoSource=String(selected.preview);
  if(v.error){if(livePlayback)failedVideo(String(v.error));else {feedbackText=String(v.error);requestId='';videoPending=false;slideshow=false;controls=true}}
  else if(v.busy!==true&&(!selected||selected.previewReady===true))requestId='';
  if(videoPending){if(v.busy!==true&&Logic.readyVideo(v,selected)){requestId='';startPreparedVideo()}}
  accepting=false;syncSlide(false)
 }
 function report(){if(active&&store)store.write('file:///tmp/cgs2-media/panel-state.json',{active:active,current:current,slideshow:slideshow,controls:controls,intervalMs:slideInterval,photoReady:photoReady,preloadReady:photo.preloadReady,transitionMode:photo.transitionMode,transitionRunning:photo.transitionRunning,transitionCount:photo.transitionCount,navigating:navigating,timerRunning:slideTimer.running,playbackState:player.playbackState,positionMs:player.position,mediaKind:selected?selected.kind:'',live:selected?selected.live===true:false,livePlayback:livePlayback,liveAdvance:liveAdvance,liveCompletedCount:liveCompletedCount,muted:player.muted,mediaStatus:player.status,durationMs:player.duration,uptime:store.uptime})}
 function refresh(){if(active&&store)store.read('file:///tmp/cgs2-media/manifest.json',function(v){p.accept(v);p.report()})}
 function stopForeground(){
  slideshow=false;slideTimer.stop();clearVideo();presence(false);requestId='';
 }
 Connections{target:p.store;ignoreUnknownSignals:true;onUptimeChanged:if(p.active&&p.store.uptime>0&&p.lastStamp===0&&p.requestId==='')p.request(false,0,0)}
 onStoreChanged:if(active&&store){presence(true);request(false,0,0);refresh()}
 Component.onCompleted:if(active&&store){presence(true);request(false,0,0);refresh()}
 onActiveChanged:{if(!active)stopForeground();else if(store){presence(true);request(false,media.offset||0,current);refresh()}}
 Component.onDestruction:stopForeground()
 onSlideshowChanged:{if(slideshow){controls=false;keepAwake();if(livePlayback&&player.playbackState===MediaPlayer.PausedState)player.play();else if(videoPending)startPreparedVideo()}else if(livePlayback){player.pause();controls=true}syncSlide(true)}
 onPhotoReadyChanged:syncSlide(true)
 onNavigatingChanged:syncSlide(false)
 onVideoPendingChanged:syncSlide(false)
 onVideoShowingChanged:syncSlide(false)
 Timer{interval:650;repeat:true;triggeredOnStart:true;running:p.active;onTriggered:{p.refresh();if(p.requestId!==''&&p.store&&p.store.uptime-p.requestAt>(p.videoPending?75:28)){p.failedVideo(p.livePlayback?'动态准备超时，保留照片':'载入超时，请重试')}}}
 Timer{interval:2000;repeat:true;running:p.active;onTriggered:p.presence(true)}
 Timer{interval:10000;repeat:true;running:p.active&&(p.slideshow||p.videoShowing);onTriggered:p.keepAwake()}
 Timer{id:slideTimer;interval:p.slideInterval;repeat:false;onTriggered:p.go(1,true)}
 PhotoSlide{id:photo;anchors.fill:parent;source:p.photoSource;preloadSource:p.nextPhoto;fillScreen:p.fillPhotos;intervalMs:p.slideInterval;slideSeed:(p.media.offset||0)+p.current;motionEnabled:p.slideshow;active:p.active&&!p.videoShowing;visible:!p.videoShowing||(p.selected&&(p.selected.kind==='audio'||p.selected.live===true&&player.position<1))}
 MediaPlayer{
  id:player;autoPlay:false;volume:.25;muted:!p.soundEnabled
  onError:if(error!==MediaPlayer.NoError&&p.preparedUrl!=='')p.failedVideo(p.livePlayback?'动态未能播放，保留照片':p.selected&&p.selected.kind==='audio'?'音乐未能解码，请换一段 MP3 音乐':'视频未能解码，请换一段 H.264 MP4 视频')
  onStatusChanged:if(status===MediaPlayer.EndOfMedia&&p.livePlayback)p.liveEnded()
  onPlaybackStateChanged:{if(playbackState===MediaPlayer.PlayingState){if(p.livePlayback&&p.selected&&p.videoItem===String(p.selected.id))p.liveStarted=true;p.videoPending=false;p.controls=false}else if(playbackState===MediaPlayer.StoppedState)p.controls=true}
 }
 VideoOutput{anchors.fill:parent;source:player;fillMode:VideoOutput.PreserveAspectFit;visible:p.videoShowing&&player.position>0&&p.selected&&(p.selected.kind==='video'||p.selected.live===true)}
 Item{anchors.fill:parent;visible:p.videoShowing&&p.selected&&p.selected.kind==='audio';FaceText{x:80;y:285;width:560;height:60;text:'♫';font.pixelSize:48;color:'#d3ad7a';horizontalAlignment:Text.AlignHCenter}FaceText{x:70;y:370;width:580;height:90;text:p.selected?p.selected.title||'NAS 音乐':'';font.pixelSize:27;horizontalAlignment:Text.AlignHCenter;elide:Text.ElideMiddle}}
 MouseArea{anchors.fill:parent;onClicked:p.controls=!p.controls}
 Rectangle{anchors.fill:parent;color:'#070c0c';visible:!p.media.enabled||!p.selected
  FaceText{x:70;y:220;width:580;height:100;text:p.pageTitle;font.pixelSize:38;horizontalAlignment:Text.AlignHCenter}
  FaceText{x:90;y:330;width:540;height:120;text:p.feedbackText||p.media.error||(p.mediaKind==='photo'?'在青萍设置页面选择照片文件夹':p.mediaKind==='video'?'在青萍设置页面单独选择视频':'在青萍设置页面单独选择音乐');font.pixelSize:23;color:'#a6b6ae';wrapMode:Text.WordWrap;horizontalAlignment:Text.AlignHCenter}
 }
 Rectangle{x:140;y:310;width:440;height:84;radius:22;color:'#d909100e';visible:!!p.selected&&p.videoPending&&!p.livePlayback
  FaceText{anchors.fill:parent;text:p.mediaKind==='audio'?'正在准备音乐…':'正在准备视频…';font.pixelSize:27;horizontalAlignment:Text.AlignHCenter}
 }
 Item{anchors.fill:parent;visible:p.controls
  Rectangle{x:0;y:0;width:720;height:105;color:'#d909100e'}
  Action{x:22;y:28;width:70;height:58;label:'‹';onClicked:p.closed()}
  FaceText{x:110;y:36;width:350;height:45;text:p.pageTitle+(p.media.albumName?' · '+p.media.albumName:'');font.pixelSize:26;elide:Text.ElideRight}
  Action{x:480;y:28;width:110;height:58;visible:p.mediaKind!=='photo'||p.selected&&p.selected.live===true;label:p.soundEnabled?'声音 开':'静音';onClicked:p.soundEnabled=!p.soundEnabled}
  Action{x:612;y:28;width:86;height:58;label:p.fillPhotos?'完整':'铺满';visible:p.mediaKind==='photo'&&!!p.selected&&!p.videoShowing;onClicked:p.fillPhotos=!p.fillPhotos}
  Rectangle{x:0;y:600;width:720;height:120;color:'#e009100e'}
  Action{x:45;y:627;width:150;height:60;label:p.mediaKind==='photo'?'‹ 上一张':'‹ 上一个';enabled:!p.navigating&&(!p.videoPending||p.livePlayback)&&Logic.target(p.media,p.current,-1,false)!==null;onClicked:p.go(-1,false)}
  Action{x:220;y:627;width:280;height:60;visible:p.mediaKind==='photo';label:p.slideshow?'暂停轮播':'随机轮播';enabled:!!p.selected&&(!p.videoPending||p.livePlayback);onClicked:p.slideshow=!p.slideshow}
  Action{x:220;y:627;width:280;height:60;visible:p.mediaKind!=='photo';label:p.videoPending?'取消准备':p.selected&&(p.selected.kind==='video'||p.selected.kind==='audio')?(player.playbackState===MediaPlayer.PlayingState?'暂停':p.selected.kind==='audio'?'播放音乐':'播放视频'):'照片';enabled:!!p.selected&&(p.selected.kind==='video'||p.selected.kind==='audio')&&!p.navigating;onClicked:p.toggleVideo()}
  Action{x:530;y:627;width:145;height:60;label:p.mediaKind==='photo'?'下一张 ›':'下一个 ›';enabled:!p.navigating&&(!p.videoPending||p.livePlayback)&&Logic.target(p.media,p.current,1,false)!==null;onClicked:p.go(1,false)}
  FaceText{x:72;y:551;width:p.feedbackText!==''?430:576;height:40;text:p.feedbackText||(photo.failed?'照片未能显示':((p.media.offset||0)+p.current+1)+' · '+(p.selected&&p.selected.kind==='video'?'视频':p.selected&&p.selected.kind==='audio'?'音乐':p.selected&&p.selected.live?'LIVE':'照片'));font.pixelSize:20;color:'#e5eee7';horizontalAlignment:Text.AlignHCenter;elide:Text.ElideRight}
  Action{x:540;y:545;width:128;height:46;label:'重试';visible:p.feedbackText!==''||photo.failed;onClicked:p.selected&&(p.selected.kind==='video'||p.selected.kind==='audio')?p.toggleVideo():p.retry()}
 }
}
