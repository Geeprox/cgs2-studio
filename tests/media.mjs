// SPDX-License-Identifier: MIT
import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
const base=new URL('../qml/',import.meta.url).pathname;const c={};vm.createContext(c);vm.runInContext(fs.readFileSync(base+'MediaLogic.js','utf8').replace('.pragma library',''),c);
const same=(a,b)=>assert.deepEqual(JSON.parse(JSON.stringify(a)),b);
assert.equal(c.interval(3000),3000);assert.equal(c.interval(1),3000);assert.equal(c.interval(100000),60000);assert.equal(c.interval(undefined),10000);
const page={items:Array.from({length:24},(_,n)=>({id:String(n+1)})),offset:0,hasMore:true};
same(c.target(page,0,-1,false),null);same(c.target(page,1,-1,false),{page:0,index:0});same(c.target(page,23,1,false),{page:24,index:0});same(c.target({...page,offset:24},0,-1,false),{page:0,index:23});
same(c.target({...page,offset:24,hasMore:false},23,1,false),null);same(c.target({...page,offset:24,hasMore:false},23,1,true),{page:0,index:0});same(c.target({items:[]},0,1,true),null);
const state={protocol:2,items:page.items,requestId:'new',stateUptimeMs:100};assert.equal(c.accept(state,'new',90),true);assert.equal(c.accept(state,'old',90),false);assert.equal(c.accept(state,'new',110),false);assert.equal(c.accept({...state,protocol:1},'',0),false);
assert.equal(c.readyPhoto({previewReady:false,preview:'file:///tmp/cgs2-media/cache/x.jpg'}),false);assert.equal(c.readyPhoto({previewReady:true,preview:'file:///tmp/cgs2-media/cache/x.jpg'}),true);assert.equal(c.readyPhoto({previewReady:true,preview:'https://arbitrary.invalid/x'}),false);
assert.equal(c.readyVideo({readyVideoId:'2'},{id:'2',kind:'video',playback:'file:///userdata/cgs2-ui/cache/media/x.mp4'}),true);assert.equal(c.readyVideo({readyVideoId:'old'},{id:'2',kind:'video',playback:'file:///userdata/cgs2-ui/cache/media/x.mp4'}),false);
const q=fs.readFileSync(base+'MediaPanel.qml','utf8');assert(!q.includes('onCurrentChanged:'));assert(q.includes("player.source='';"));assert(q.includes('function syncSlide(restart)'));assert(q.includes('onPhotoReadyChanged:syncSlide(true)'));assert(!q.includes('running:p.slideshow'));assert(q.includes('!store.nightWindowActive'));
assert.equal(c.nextPreview({items:[{previewReady:true,preview:'file:///tmp/cgs2-media/cache/1.jpg'},{previewReady:true,preview:'file:///tmp/cgs2-media/cache/2.jpg'}],offset:0,hasMore:false},0),'file:///tmp/cgs2-media/cache/2.jpg');
assert.equal(c.nextPreview({items:[{previewReady:true,preview:'file:///tmp/cgs2-media/cache/1.jpg'},{previewReady:false,preview:''}],offset:0},0),'');
assert.equal(c.nextPreview(page,23),'');
assert(!q.includes('正在载入照片'));assert(q.includes('preloadSource:p.nextPhoto'));
console.log('PASS media navigation/readiness, prefetch publication, no loading toast and lifecycle checks (Node JS; not native Qt)');

const shuffled={...page,mediaKind:'photo',nextPage:0,nextIndex:17,nextPreview:'file:///tmp/cgs2-media/cache/18.jpg'};
same(c.target(shuffled,0,1,true),{page:0,index:17});
same(c.target({...shuffled,nextPreview:''},0,1,true),null);
assert.equal(c.nextPreview(shuffled,0),shuffled.nextPreview);
same(c.target({...page,offset:24,hasPrevious:false},0,-1,false),null);

// A paired Live Photo can play its published local compatibility clip.
assert.equal(c.readyVideo({readyVideoId:''},{id:'7',kind:'photo',live:true,liveReady:true,playback:'file:///userdata/cgs2-ui/cache/media/clip.mp4'}),true);
assert.equal(c.readyVideo({readyVideoId:''},{id:'7',kind:'photo',live:true,liveReady:true,playback:'https://example.com/motion.mov'}),false);
