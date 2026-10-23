// SPDX-License-Identifier: MIT
import fs from 'node:fs';
import https from 'node:https';
import {randomBytes} from 'node:crypto';
type Settings={enabled:boolean;albumLink:string;deviceId:string;intervalMs:number;revision:string};
type Photo={id:number;type:string;additional?:{thumbnail?:{cache_key?:string;unit_id?:number};video_convert?:{quality:string;metadata?:{video_codec?:string;duration?:number;frame_bitrate?:number}}[]}};
export function albumToken(link:unknown):string{
 if(typeof link!=='string'||link.length>1024)throw Error('请填写 Synology Photos 相册共享链接');
 const u=new URL(link);if(u.protocol!=='https:'||u.username||u.password||u.search||u.hash)throw Error('仅接受 HTTPS 相册共享链接');
 const m=u.pathname.match(/^\/mo\/sharing\/([A-Za-z0-9_-]{1,128})\/?$/);if(!m)throw Error('请使用相册共享链接，不使用 DSM 登录地址');return m[1];
}
export class PhotosMedia{
 private value:Settings={enabled:false,albumLink:'',deviceId:'',intervalMs:10000,revision:''};
 private context?:{sharing:string;phrase:string;expires:number};private items=new Map<number,Photo>();private queue=0;
 private cookies=new Map<string,string>();
 private agent:https.Agent;
 constructor(private file:string,nasIp:string,private sourceOrigin:string){
  const u=new URL(sourceOrigin);if(u.protocol!=='https:'||u.origin!==sourceOrigin||u.port!=='5001')throw Error('Invalid Photos source');
  this.agent=new https.Agent({keepAlive:true,maxSockets:2,lookup:((_h:unknown,o:any,cb:Function)=>o?.all?cb(null,[{address:nasIp,family:4}]):cb(null,nasIp,4)) as any});
  try{const v=JSON.parse(fs.readFileSync(file,'utf8'));if(v.enabled)albumToken(v.albumLink);if(typeof v.enabled==='boolean'&&typeof v.deviceId==='string'&&Number.isInteger(v.intervalMs)&&v.intervalMs>=3000&&v.intervalMs<=60000)this.value=v;}catch{}
 }
 publicSettings(){const {enabled,deviceId,intervalMs,revision}=this.value;return {enabled,deviceId,intervalMs,revision,configured:!!this.value.albumLink,source:'Synology Photos'};}
 configure(body:Record<string,unknown>,knownIds:string[]){
  if(Object.keys(body).some(k=>!['enabled','albumLink','deviceId','intervalMs'].includes(k)))throw Error('Invalid media settings');
  if(typeof body.enabled!=='boolean'||typeof body.deviceId!=='string'||!knownIds.includes(body.deviceId)||!Number.isInteger(body.intervalMs)||Number(body.intervalMs)<3000||Number(body.intervalMs)>60000)throw Error('请选择已配对设备和 3–60 秒轮播间隔');
  const link=body.albumLink===''?this.value.albumLink:String(body.albumLink||'');if(body.enabled)albumToken(link);
  this.value={enabled:body.enabled,albumLink:link,deviceId:body.deviceId,intervalMs:Number(body.intervalMs),revision:randomBytes(12).toString('hex')};
  fs.writeFileSync(this.file+'.new',JSON.stringify(this.value)+'\n',{mode:0o600});fs.renameSync(this.file+'.new',this.file);this.context=undefined;this.cookies.clear();this.items.clear();return this.publicSettings();
 }
 allowed(id:string){return this.value.enabled&&this.value.deviceId===id;}
 private async request(route:string,params?:Record<string,unknown>,max=1024*1024,timeoutMs=12000):Promise<Buffer>{
  return new Promise((resolve,reject)=>{
   const encoded=params?new URLSearchParams(Object.entries(params).map(([k,v])=>[k,['api','method','version'].includes(k)?String(v):JSON.stringify(v)])).toString():'';
   const req=https.request(new URL(route,this.sourceOrigin),{agent:this.agent,method:params?'POST':'GET',headers:{...(this.cookies.size?{Cookie:Array.from(this.cookies.values()).join('; ')}:{}),...(params?{'Content-Type':'application/x-www-form-urlencoded','Content-Length':Buffer.byteLength(encoded)}:{})}},res=>{
    for(const raw of res.headers['set-cookie']||[]){const pair=raw.split(';',1)[0];if(/^[A-Za-z0-9_-]+=[^\r\n;]{0,4096}$/.test(pair))this.cookies.set(pair.split('=',1)[0],pair);}
    if(res.statusCode!==200){res.resume();reject(Error('Photos source unavailable'));return;}
    const chunks:Buffer[]=[];let length=0;res.on('data',(b:Buffer)=>{length+=b.length;if(length>max){req.destroy(Error('Photos response too large'));return;}chunks.push(b)});res.on('end',()=>resolve(Buffer.concat(chunks)));res.on('error',()=>reject(Error('Photos response interrupted')));
   });const timer=setTimeout(()=>req.destroy(Error('Photos request timed out')),timeoutMs);req.on('close',()=>clearTimeout(timer));req.on('error',()=>reject(Error('Photos source unavailable')));req.end(encoded);
  });
 }
 private async session(){
  if(this.context&&this.context.expires>Date.now())return this.context;
  const html=(await this.request('/mo/sharing/'+albumToken(this.value.albumLink),undefined,128*1024)).toString();
  const sharing=html.match(/sharing_id:\s*"([^"\r\n]{1,256})"/)?.[1],phrase=html.match(/passphrase:\s*"([^"\r\n]{1,256})"/)?.[1];
  if(!sharing||!phrase||!/enable_password:\s*false/.test(html))throw Error('此相册需要登录、密码或共享链接已失效');
  return this.context={sharing,phrase,expires:Date.now()+5*60000};
 }
 private async api(api:string,version:number,method:string,args:Record<string,unknown>){const ctx=await this.session();const d=JSON.parse((await this.request('/mo/sharing/webapi/entry.cgi',{api,version,method,_sharing_id:ctx.sharing,passphrase:ctx.phrase,...args})).toString());if(!d.success){this.context=undefined;throw Error('Photos 拒绝访问，请检查共享链接');}return d.data;}
 async manifest(id:string,offset:number){
  if(!this.allowed(id))return {enabled:false,items:[],albumName:'未选择相册'};
  if(!Number.isInteger(offset)||offset<0||offset>100000)throw Error('Invalid offset');
  const revision=this.value.revision,d=await this.api('SYNO.Foto.Browse.Item',7,'list',{offset,limit:25,sort_by:'takentime',sort_direction:'asc',additional:['thumbnail','video_convert','video_meta']});
  if(revision!==this.value.revision)throw Error('Media settings changed');
  const raw=Array.isArray(d.list)?d.list.slice(0,25):[];const list=raw.slice(0,24).filter((p:Photo)=>Number.isSafeInteger(p.id)&&['photo','video'].includes(p.type)).slice(0,24);this.items.clear();for(const p of list)this.items.set(p.id,p);
  return {enabled:true,revision,albumName:'Synology Photos',intervalMs:this.value.intervalMs,offset,hasMore:raw.length>24,items:list.map((p:Photo)=>({id:String(p.id),kind:p.type==='video'?'video':'photo',preview:'/api/media/item/'+p.id+'/preview?revision='+revision,playback:p.type==='video'?'/api/media/item/'+p.id+'/video?revision='+revision:undefined}))};
 }
 async bytes(id:string,itemId:number,revision:string,kind:'preview'|'video'){
  if(!this.allowed(id)||revision!==this.value.revision||!this.items.has(itemId))throw Error('Media access expired');
  if(this.queue>=2)throw Error('Media busy');this.queue++;
  try{
   const item=this.items.get(itemId)!,ctx=await this.session();let b:Buffer;
   if(kind==='preview'){
    const th=item.additional?.thumbnail;if(!th||typeof th.cache_key!=='string'||th.cache_key.length>200)throw Error('Preview unavailable');
    const p={id:th.unit_id||item.id,cache_key:th.cache_key,type:'unit',size:'xl',passphrase:ctx.phrase,_sharing_id:ctx.sharing};
    b=await this.request('/synofoto/api/v2/p/Thumbnail/get?'+new URLSearchParams(Object.entries(p).map(([k,v])=>[k,JSON.stringify(v)])).toString(),undefined,4*1024*1024);
    if(b[0]!==0xff||b[1]!==0xd8)throw Error('JPEG preview unavailable');if(!this.allowed(id)||revision!==this.value.revision)throw Error('Media settings changed');return {body:b,type:'image/jpeg'};
   }
   if(item.type!=='video')throw Error('Not a video');
   const variants=Array.isArray(item.additional?.video_convert)?item.additional!.video_convert!:[];
   const converted=variants.filter(v=>v.metadata?.video_codec==='h264').sort((a,b)=>(a.metadata?.frame_bitrate||0)-(b.metadata?.frame_bitrate||0))[0];
   if(!converted||!['high','medium','low'].includes(converted.quality)||(converted.metadata?.duration||0)*(converted.metadata?.frame_bitrate||0)/8000>64*1024*1024)throw Error('请在 NAS 生成 64 MB 以内的 H.264 兼容预览');
   b=await this.request('/mo/sharing/webapi/entry.cgi',{api:'SYNO.Foto.Streaming',version:2,method:'streaming',id:item.id,type:'unit',quality:converted.quality,passphrase:ctx.phrase,_sharing_id:ctx.sharing},64*1024*1024,60000);
   if(b.toString('ascii',4,8)!=='ftyp')throw Error('兼容 MP4 暂不可用，请先在 Synology Photos 生成预览');if(!this.allowed(id)||revision!==this.value.revision)throw Error('Media settings changed');return {body:b,type:'video/mp4'};
  }finally{this.queue--;}
 }
 close(){this.agent.destroy();}
}
