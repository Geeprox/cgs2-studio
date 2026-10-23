// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import https from 'node:https';
import http from 'node:http';
import {execFileSync} from 'node:child_process';
import {NasMedia,parseRange} from './dist/nas-media.js';
import {createMediaServer,privateHost,secureEqual} from './server.mjs';
const key=p=>Buffer.from(p).toString('base64url');
test('strict byte ranges, private interfaces and independent credentials',()=>{
 assert.deepEqual(parseRange('bytes=4-9',16),{start:4,end:9,status:206});assert.deepEqual(parseRange('bytes=-4',16),{start:12,end:15,status:206});
 for(const r of ['bytes=0-1,4-5','bytes=16-','bytes=-','bytes=2-1'])assert.throws(()=>parseRange(r,16));
 assert(privateHost('10.0.0.1'));for(const ip of ['127.0.0.1','8.8.8.8','010.0.0.1','nas.local'])assert(!privateHost(ip));
 assert(secureEqual('secret','secret'));assert(!secureEqual('secret','other'));
});
test('selected-only media, symlink fencing, stale revisions and streaming ranges',async()=>{
 const tmp=fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(),'cgs2-media-test-'))),root=path.join(tmp,'media');fs.mkdirSync(root);
 const movie=path.join(root,'test.mp4');fs.writeFileSync(movie,Buffer.from('0000ftypabcdefghijklmnop'));fs.symlinkSync(os.tmpdir(),path.join(root,'linked'));
 const media=new NasMedia(path.join(tmp,'settings.json'),{roots:[{path:root,label:'Media'}],placeholder:Buffer.alloc(1)});
 assert.throws(()=>media.browse({location:key(path.join(root,'linked')),kind:'video'}));assert.throws(()=>media.browse({location:key(tmp)}));
 media.configure({source:'nas',enabled:true,deviceId:'cgs2',intervalMs:3000,folder:'',files:[key(movie)],recursive:false},['cgs2']);
 assert.equal((await media.manifest('wrong',0)).enabled,false);
 const manifest=await media.manifest('cgs2',0),item=manifest.items[0];assert.equal(item.kind,'video');assert.equal(manifest.intervalMs,3000);
 const server=http.createServer(async(req,res)=>{try{await media.stream('cgs2',item.id,manifest.revision,req,res);}catch{res.writeHead(409);res.end();}});
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 async function request(range,method='GET'){return new Promise((resolve,reject)=>{const req=http.request({host:'127.0.0.1',port:server.address().port,headers:{Range:range},method},res=>{const chunks=[];res.on('data',c=>chunks.push(c));res.on('end',()=>resolve({status:res.statusCode,headers:res.headers,body:Buffer.concat(chunks)}));});req.on('error',reject);req.end();});}
 try{
  const r=await request('bytes=4-9');assert.equal(r.status,206);assert.equal(r.body.toString(),'ftypab');assert.equal(r.headers['content-range'],'bytes 4-9/24');
  const h=await request('bytes=4-9','HEAD');assert.equal(h.status,206);assert.equal(h.body.length,0);assert.equal(h.headers['content-length'],'6');
  assert.equal((await request('bytes=30-')).status,416);
  fs.appendFileSync(movie,'changed');assert.equal((await request('bytes=0-3')).status,409);
 }finally{await new Promise(r=>server.close(r));media.close();fs.rmSync(tmp,{recursive:true,force:true});}
});
test('TLS gateway authentication, scope and browser origin',async()=>{
 const tmp=fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(),'cgs2-gateway-test-'))),root=path.join(tmp,'media');fs.mkdirSync(root);
 fs.writeFileSync(path.join(tmp,'admin-token'),'a'.repeat(64));fs.writeFileSync(path.join(tmp,'device-token'),'b'.repeat(64));
 execFileSync('openssl',['req','-x509','-newkey','rsa:2048','-nodes','-days','1','-subj','/CN=localhost','-keyout',path.join(tmp,'server.key'),'-out',path.join(tmp,'server.pem')],{stdio:'ignore'});
 const config={host:'10.0.0.1',port:6080,roots:[{path:root,label:'Media'}]},server=createMediaServer(config,tmp);
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const request=(route,token,method='GET',origin,body)=>new Promise((resolve,reject)=>{const req=https.request({host:'127.0.0.1',port:server.address().port,rejectUnauthorized:false,path:route,method,headers:{Host:config.host+':'+config.port,...(token?{Authorization:'Bearer '+token}:{}),...(origin?{Origin:origin}:{})}},res=>{res.resume();res.on('end',()=>resolve(res.statusCode));});req.on('error',reject);req.end(body?JSON.stringify(body):undefined);});
 try{
  assert.equal(await request('/api/media/settings'),401);
  assert.equal(await request('/api/media/settings','b'.repeat(64)),403);
  assert.equal(await request('/api/media/settings','a'.repeat(64)),200);
  assert.equal(await request('/api/media/manifest','b'.repeat(64)),200);
  assert.equal(await request('/api/media/browse','a'.repeat(64),'POST',undefined,{}),403);
  assert.equal(await request('/api/media/browse','a'.repeat(64),'POST','https://evil.invalid',{}),403);
  assert.equal(await request('/api/media/browse','a'.repeat(64),'POST','https://10.0.0.1:6080',{}),200);
 }finally{await new Promise(r=>server.close(r));fs.rmSync(tmp,{recursive:true,force:true});}
});

import {appleStillIdentifier,quickTimeIdentifier,pairingIdentifier} from './dist/live-photo.js';
const asset='11111111-2222-4333-8444-555555555555';
function still(identifier=asset){const b=Buffer.alloc(96);b.write('Apple iOS\0');b.writeUInt16BE(1,10);b.write('MM',12);b.writeUInt16BE(1,14);b.writeUInt16BE(17,16);b.writeUInt16BE(2,18);b.writeUInt32BE(37,20);b.writeUInt32BE(32,24);b.write(identifier+'\0',32);return b;}
function atom(type,...data){let b=Buffer.concat(data),h=Buffer.alloc(8);h.writeUInt32BE(b.length+8);typeof type==='number'?h.writeUInt32BE(type,4):h.write(type,4);return Buffer.concat([h,b]);}
function movie(identifier=asset,fullBox=true){const n=Buffer.alloc(8);n.writeUInt32BE(1,4);const data=Buffer.alloc(8);data.writeUInt32BE(1);return Buffer.concat([atom('ftyp',Buffer.from('qt  ')),atom('moov',atom('meta',fullBox?Buffer.alloc(4):Buffer.alloc(0),atom('keys',n,atom('mdta',Buffer.from('com.apple.quicktime.content.identifier'))),atom('ilst',atom(1,atom('data',data,Buffer.from(identifier))))))]);}
test('bounded Live Photo pairing reads matching identifiers, rejects malformed metadata',()=>{
 assert.equal(appleStillIdentifier(still()),asset);assert.equal(quickTimeIdentifier(movie()),asset);assert.equal(quickTimeIdentifier(movie(asset,false)),asset);
 for(let n=0;n<still().length;n++)assert.doesNotThrow(()=>appleStillIdentifier(still().subarray(0,n)));
 const malformed=still();malformed.writeUInt32BE(0xffffffff,24);assert.equal(appleStillIdentifier(malformed),'');
 const wrong=movie().subarray(0,25);assert.equal(quickTimeIdentifier(wrong),'');assert.equal(appleStillIdentifier(Buffer.from(asset)),'');
});
test('typed pages skip photo scans in UI, Live pairing remains selected-only and stale-safe',async()=>{
 const tmp=fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(),'cgs2-live-test-'))),root=path.join(tmp,'media');fs.mkdirSync(root);
 const matching=path.join(root,'a.jpg'),matchedMovie=path.join(root,'a.MOV'),unmatched=path.join(root,'b.jpg');fs.writeFileSync(matching,still());fs.writeFileSync(matchedMovie,movie());fs.writeFileSync(unmatched,still());fs.writeFileSync(path.join(root,'b.MOV'),movie('aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'));
 const outside=path.join(tmp,'outside.MOV');fs.writeFileSync(outside,movie());fs.writeFileSync(path.join(root,'c.jpg'),still());fs.symlinkSync(outside,path.join(root,'c.MOV'));
 for(let i=0;i<50;i++)fs.writeFileSync(path.join(root,'plain-'+i+'.jpg'),Buffer.from('not-live'));
 const video=path.join(root,'selected.mp4'),audio=path.join(root,'selected.mp3');fs.writeFileSync(video,movie());fs.writeFileSync(audio,'audio');
 const media=new NasMedia(path.join(tmp,'settings.json'),{roots:[{path:root,label:'Media'}],placeholder:Buffer.alloc(1)});
 media.configure({source:'nas',enabled:true,deviceId:'cgs2',intervalMs:3000,folder:key(root),files:[key(video),key(audio)],recursive:true},['cgs2']);
 try{
  assert.equal((await media.manifest('cgs2',0,'video')).items.length,1);assert.equal((await media.manifest('cgs2',0,'audio')).items[0].kind,'audio');
  const photos=await media.manifest('cgs2',0,'photo');assert.equal(photos.total,53);assert(photos.items.every(i=>i.kind==='photo'));assert.equal(photos.items.find(i=>i.title==='a.jpg').live,true);assert.equal(photos.items.find(i=>i.title==='b.jpg').live,false);assert.equal(photos.items.find(i=>i.title==='c.jpg').live,false);
  assert.equal(pairingIdentifier(matching),asset);assert.equal(pairingIdentifier(matchedMovie,true),asset);assert(!JSON.stringify(photos).includes(asset));assert(!JSON.stringify(photos).includes(tmp));
  await assert.rejects(media.manifest('cgs2',0,'wrong'));
  fs.writeFileSync(matchedMovie,movie('aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'));
  const item=photos.items.find(i=>i.title==='a.jpg');await assert.rejects(media.stream('cgs2',item.id,photos.revision,{headers:{}},{writeHead(){},end(){}}));
 }finally{media.close();fs.rmSync(tmp,{recursive:true,force:true});}
});

import {LiveCache} from './dist/live-cache.js';
test('compatibility clips share bounded work, retain a cache, cancel on settings change',async()=>{
 const tmp=fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(),'cgs2-clip-test-'))),source=path.join(tmp,'source.mov'),tool=path.join(tmp,'ffmpeg');fs.writeFileSync(source,movie());
 const output=path.join(tmp,'sample.mp4');fs.writeFileSync(output,movie());
 fs.writeFileSync(tool,'#!/bin/sh\nfor last;do :;done\n/bin/cp '+JSON.stringify(output)+' "$last"\n',{mode:0o700});
 const cache=new LiveCache(path.join(tmp,'cache'),()=>tool);
 try{
  const file=await cache.prepare(source,'one');assert(fs.existsSync(file));assert.equal(await cache.prepare(source,'one'),file);assert.equal(fs.statSync(file).mode&0o777,0o600);
  fs.writeFileSync(tool,'#!/bin/sh\nexec sleep 10\n',{mode:0o700});const pending=cache.prepare(source,'two');await assert.rejects(cache.prepare(source,'three'));cache.close();await assert.rejects(pending);
 }finally{cache.close();fs.rmSync(tmp,{recursive:true,force:true});}
});
