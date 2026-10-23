// SPDX-License-Identifier: MIT
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const qml=fs.readFileSync(require('path').join(__dirname,'../qml/UiState.qml'),'utf8');
function extract(name){const start=qml.indexOf(' function '+name+'('),open=qml.indexOf('{',start);let depth=1,i=open+1;for(;depth;i++){if(qml[i]==='{')depth++;if(qml[i]==='}')depth--;}return qml.slice(start,i).trim();}
const writes=[];const c={uptime:0,displayAwake:true,idleLastTouchUptime:-1,idleDimRequested:false,idleDimTimeoutSeconds:60,nativeScreenAvailable:true,screenManager:{},queueScreenState(){}};
Object.defineProperty(c.screenManager,'brightnessValue',{set(v){writes.push(v)}});vm.createContext(c);vm.runInContext(extract('restoreIdleBrightness')+'\n'+extract('updateIdleBrightness'),c);
c.updateIdleBrightness();assert.equal(writes.length,0);c.uptime=100;c.updateIdleBrightness();c.uptime=159;c.updateIdleBrightness();assert.equal(writes.length,0);c.uptime=160;c.updateIdleBrightness();assert.deepEqual(writes,[-1001]);c.uptime=161;c.updateIdleBrightness();assert.equal(writes.length,1);
c.restoreIdleBrightness();assert.equal(writes.at(-1),-1000);assert.equal(c.idleLastTouchUptime,161);c.uptime=220;c.updateIdleBrightness();assert.equal(writes.length,2);c.uptime=221;c.updateIdleBrightness();assert.equal(writes.at(-1),-1001);
c.displayAwake=false;c.idleDimRequested=false;c.uptime=1000;c.updateIdleBrightness();assert.equal(writes.length,3);c.displayAwake=true;c.restoreIdleBrightness();c.uptime=1059;c.updateIdleBrightness();assert.equal(writes.length,4);c.uptime=1060;c.updateIdleBrightness();assert.equal(writes.at(-1),-1001);
c.uptime=1;c.idleDimRequested=false;c.updateIdleBrightness();assert.equal(c.idleLastTouchUptime,1);
assert(qml.includes('function onInterfaceTouched(){s.restoreIdleBrightness()}'));assert(!extract('poll').includes('restoreIdleBrightness'));
console.log(JSON.stringify({passed:true,realFunctions:true,monotonicTimeoutSeconds:60,offGate:true,touchRestartsDeadline:true,mediaAndAnimationRefreshCannotResetDeadline:true}));
