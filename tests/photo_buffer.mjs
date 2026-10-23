// SPDX-License-Identifier: MIT
// State harness executes the actual QML transition functions; rendering is tested on Qt separately.
import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
const text=fs.readFileSync(new URL('../qml/PhotoSlide.qml',import.meta.url),'utf8');
function extract(name){const start=text.indexOf('function '+name+'(');assert(start>=0);let at=text.indexOf('{',start),depth=1;for(let i=at+1;i<text.length;i++){if(text[i]==='{')depth++;if(text[i]==='}'&&!--depth)return text.slice(start,i+1)}}
const img=url=>({source:url,status:1,progress:0,implicitWidth:1280,implicitHeight:720});
const anim=()=>({running:false,stop(){this.running=false},start(){this.running=true},restart(){this.running=true}});
const logic={};vm.createContext(logic);vm.runInContext(fs.readFileSync(new URL('../qml/MediaLogic.js',import.meta.url),'utf8').replace('.pragma library',''),logic);
const c={Logic:logic,width:720,height:720,a:img('current'),b:img(''),za:anim(),zb:anim(),cross:anim(),transitionCount:0,transitionMode:0,transitionProgress:1,Image:{Ready:1},active:true,pending:-1,shown:0,source:'current',preloadSource:'next',motionEnabled:false,fillScreen:true,slideSeed:1,intervalMs:3000,failed:false,warmTimer:{restart(){}}};
Object.defineProperty(c,'displayedSource',{get(){return this.shown<0?'':this.image(this.shown).source;}});
vm.createContext(c);vm.runInContext(['image','animation','syncMotion','warm','load','loaded'].map(extract).join('\n'),c);
c.warm();assert.equal(c.a.source,'current');assert.equal(c.shown,0);assert.equal(c.b.source,'next');
c.source='next';c.load();assert.equal(c.shown,1);assert.equal(c.pending,-1);assert.equal(c.failed,false);assert(c.cross.running);assert.equal(c.transitionCount,1);
c.preloadSource='slow';c.warm();assert.equal(c.a.source,'current'); // Preserve outgoing texture until transition ends.
c.cross.running=false;c.transitionProgress=1;c.warm();assert.equal(c.a.source,'slow');
c.a.status=2;c.source='slow';c.load();assert.equal(c.shown,1);assert.equal(c.b.source,'next');assert.equal(c.pending,0);
c.loaded(1);assert.equal(c.pending,0);c.a.status=1;c.loaded(0);assert.equal(c.shown,0);assert.equal(c.pending,-1);
c.active=false;c.cross.running=false;c.preloadSource='hidden';c.warm();assert.notEqual(c.b.source,'hidden');
console.log('PASS photo decode warmup, transition texture preservation, slow download holds current image, stale callback and hidden lifecycle');
