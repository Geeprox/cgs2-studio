// SPDX-License-Identifier: MIT
// An independent media-only gateway. Explicit roots and separate admin/device keys.
import fs from 'node:fs';
import path from 'node:path';
import https from 'node:https';
import {timingSafeEqual} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {NasMedia} from './dist/nas-media.js';
import {PhotosMedia} from './dist/photos.js';
import {mediaPlaceholder} from './dist/media-placeholder.js';
export function secureEqual(a,b){const x=Buffer.from(a||''),y=Buffer.from(b);return x.length===y.length&&timingSafeEqual(x,y);}
export function privateHost(host){const x=host.split('.');if(x.length!==4||x.some(v=>!/^\d{1,3}$/.test(v)||String(Number(v))!==v||Number(v)>255))return false;const n=x.map(Number);return n[0]===10||n[0]===192&&n[1]===168||n[0]===172&&n[1]>=16&&n[1]<=31;}
export function createMediaServer(config,privateDir){
 if(!privateHost(config.host)||!Number.isInteger(config.port)||config.port<1||config.port>65535||!Array.isArray(config.roots)||!config.roots.length)throw Error('Explicit private LAN host, port and media roots required');
 const origins='https://'+config.host+':'+config.port,admin=fs.readFileSync(path.join(privateDir,'admin-token'),'utf8').trim(),device=fs.readFileSync(path.join(privateDir,'device-token'),'utf8').trim();
 if(!/^[a-f0-9]{64}$/.test(admin)||!/^[a-f0-9]{64}$/.test(device)||admin===device)throw Error('Separate random credentials required');
 const roots=config.roots.map(r=>{const file=path.resolve(r.path);if(fs.realpathSync(file)!==file||fs.lstatSync(file).isSymbolicLink())throw Error('Roots must be canonical directories');return {path:file,label:String(r.label||path.basename(file))};});
 const nas=new NasMedia(path.join(privateDir,'nas-media.json'),{roots,placeholder:mediaPlaceholder,ffmpeg:config.ffmpeg,convert:config.convert});
 const photos=config.photos?new PhotosMedia(path.join(privateDir,'photos.json'),config.photos.lanIp,config.photos.origin):null;
 const selected=()=>nas.source()==='photos'?photos:nas;
 const settings=()=>({...nas.settings(),...(nas.source()==='photos'&&photos?photos.publicSettings():{}),source:nas.source()==='photos'&&photos?'photos':'nas',deviceId:'cgs2',photosAvailable:!!photos});
 const json=(res,code,data)=>{const body=JSON.stringify(data);res.writeHead(code,{'Content-Type':'application/json; charset=utf-8','Content-Length':Buffer.byteLength(body),'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});res.end(body);};
 async function body(req){let value='';for await(const chunk of req){value+=chunk;if(value.length>16384)throw Error('Request too large');}const o=JSON.parse(value);if(!o||Array.isArray(o)||typeof o!=='object')throw Error('Object required');return o;}
 const server=https.createServer({key:fs.readFileSync(path.join(privateDir,'server.key')),cert:fs.readFileSync(path.join(privateDir,'server.pem')),minVersion:'TLSv1.2'},async(req,res)=>{
  res.setHeader('Cache-Control','no-store');
  if(req.headers.host!==config.host+':'+config.port){json(res,403,{error:'Invalid host'});return;}
  let url;try{url=new URL(req.url,origins);}catch{json(res,400,{error:'Invalid request'});return;}
  const route=url.pathname;
  if(req.method==='GET'&&route==='/'){
   const page=fs.readFileSync(new URL('./settings.html',import.meta.url));res.writeHead(200,{'Content-Type':'text/html; charset=utf-8','Content-Security-Policy':"default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'",'X-Content-Type-Options':'nosniff'});res.end(page);return;
  }
  if(req.method==='GET'&&['/settings.js','/settings.css'].includes(route)){
   const bytes=fs.readFileSync(new URL('.'+route,import.meta.url));res.writeHead(200,{'Content-Type':route.endsWith('.js')?'application/javascript':'text/css','X-Content-Type-Options':'nosniff'});res.end(bytes);return;
  }
  const authorization=req.headers.authorization;
  const isAdmin=secureEqual(authorization,'Bearer '+admin),isDevice=secureEqual(authorization,'Bearer '+device);
  if(!isAdmin&&!isDevice){json(res,401,{error:'Authentication required'});return;}
  // Reject duplicate security headers before parsing bodies or accessing files.
  for(const name of ['host','authorization','origin'])if(req.rawHeaders.filter((v,i)=>i%2===0&&v.toLowerCase()===name).length>1){json(res,403,{error:'Duplicate security header'});return;}
  if(req.headers.origin!==undefined&&req.headers.origin!==origins){json(res,403,{error:'Invalid origin'});return;}
  try{
   if(route==='/api/media/settings'&&isAdmin){
    if(req.method==='GET'){json(res,200,settings());return;}
    if(req.method==='POST'&&req.headers.origin===origins){
     const o=await body(req);o.deviceId='cgs2';
     if(o.source==='photos'){
      if(!photos)throw Error('Photos provider is not configured');
      photos.configure({enabled:o.enabled,deviceId:o.deviceId,intervalMs:o.intervalMs,albumLink:o.albumLink||''},['cgs2']);
      nas.configure({source:'photos',enabled:o.enabled,deviceId:o.deviceId,intervalMs:o.intervalMs},['cgs2']);
     }else nas.configure(o,['cgs2']);
     json(res,200,settings());return;
    }
   }
   if(route==='/api/media/browse'&&isAdmin&&req.method==='POST'&&req.headers.origin===origins){json(res,200,nas.browse(await body(req)));return;}
   if(isDevice&&['GET','HEAD'].includes(req.method)){
    const provider=selected();
    if(route==='/api/media/manifest'){json(res,200,provider?await provider.manifest('cgs2',Number(url.searchParams.get('offset')||0)):{enabled:false,items:[]});return;}
    const m=route.match(/^\/api\/media\/item\/([0-9]{1,12})\/(preview|video)$/),revision=url.searchParams.get('revision')||'';
    if(m&&provider&&provider.allowed('cgs2')){
     if(provider===nas){
      if(m[2]==='video'){await nas.stream('cgs2',m[1],revision,req,res);return;}
      const image=await nas.preview('cgs2',m[1],revision);if(!nas.allowed('cgs2'))throw Error('Selection changed');
      res.writeHead(200,{'Content-Type':'image/jpeg','Content-Length':image.length});res.end(req.method==='HEAD'?undefined:image);return;
     }
     const item=await photos.bytes('cgs2',Number(m[1]),revision,m[2]);res.writeHead(200,{'Content-Type':item.type,'Content-Length':item.body.length});res.end(req.method==='HEAD'?undefined:item.body);return;
    }
   }
   json(res,403,{error:'Unavailable route or permission'});
  }catch{if(!res.headersSent)json(res,400,{error:'Media selection unavailable; check source and supported preview'});else res.destroy();}
 });
 server.requestTimeout=15000;server.headersTimeout=10000;server.maxConnections=12;
 server.on('close',()=>{nas.close();photos?.close();});
 return server;
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const privateDir=path.resolve(process.argv[2]||'../../.local/nas');
 const config=JSON.parse(fs.readFileSync(path.join(privateDir,'server.json'),'utf8'));
 const server=createMediaServer(config,privateDir);server.listen(config.port,config.host,()=>console.log('CGS2 media service ready; authenticated LAN access only'));
 const stop=()=>server.close();process.on('SIGTERM',stop);process.on('SIGINT',stop);
}
