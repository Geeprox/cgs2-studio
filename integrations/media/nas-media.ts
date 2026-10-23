// SPDX-License-Identifier: MIT
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import {createHash,randomBytes} from 'node:crypto';
import {spawn} from 'node:child_process';
import type {IncomingMessage,ServerResponse} from 'node:http';

type Source={source:'photos'|'nas';enabled:boolean;deviceId:string;intervalMs:number;folder:string;files:string[];recursive:boolean;revision:string};
type Root={label:string;path:string};
type Item={id:string;file:string;size:number;mtime:number;ino:number;kind:'photo'|'video'|'audio'};
const photo=new Set(['.jpg','.jpeg','.png','.webp','.bmp','.heic','.heif']);
const video=new Set(['.mp4','.m4v','.mov','.mkv','.webm','.avi','.ts']);
const audio=new Set(['.mp3','.m4a','.wav','.flac','.ogg']);
const hidden=(n:string)=>n.startsWith('.')||n.startsWith('@')||n.startsWith('#');
const hash=(s:string)=>createHash('sha256').update(s).digest('hex');
const key=(p:string)=>Buffer.from(p).toString('base64url');
function smallRaster(b:Buffer){
 if(b.length>=24&&b.toString('ascii',1,4)==='PNG')return b.readUInt32BE(16)*b.readUInt32BE(20)<=2000000;
 if(b[0]!==255||b[1]!==216)return false;let p=2;
 while(p+8<b.length){if(b[p++]!==255)return false;while(b[p]===255)p++;const marker=b[p++];if(marker===0xd9||marker===0xda)return false;if(marker===0x01||marker>=0xd0&&marker<=0xd7)continue;const n=b.readUInt16BE(p);if(n<2||p+n>b.length)return false;if([0xc0,0xc1,0xc2,0xc3,0xc5,0xc6,0xc7,0xc9,0xca,0xcb,0xcd,0xce,0xcf].includes(marker))return b.readUInt16BE(p+3)*b.readUInt16BE(p+5)<=2000000;p+=n;
 }return false;
}
function decode(v:unknown){if(typeof v!=='string'||v.length>4096||!/^[A-Za-z0-9_-]+$/.test(v))throw Error('请选择 NAS 文件或文件夹');const s=Buffer.from(v,'base64url').toString();if(key(s)!==v||s.includes('\0')||!path.isAbsolute(s))throw Error('文件位置无效');return s;}
export function parseRange(value:string|undefined,size:number){
 if(value===undefined)return {start:0,end:size-1,status:200};
 const m=/^bytes=(\d{0,14})-(\d{0,14})$/.exec(value);if(!m||(!m[1]&&!m[2])||size===0)throw Error('range');
 let start=m[1]?Number(m[1]):Math.max(0,size-Number(m[2])),end=m[1]?(m[2]?Number(m[2]):size-1):size-1;
 if(!Number.isSafeInteger(start)||!Number.isSafeInteger(end)||start>=size||start<0||end<start)throw Error('range');return {start,end:Math.min(end,size-1),status:206};
}
export class NasMedia{
 private value:Source={source:'photos',enabled:false,deviceId:'',intervalMs:10000,folder:'',files:[],recursive:true,revision:''};
 private items=new Map<string,Item>();private listed:Item[]=[];private currentRevision='';private indexedAt=0;private indexing?:Promise<void>;private previews=new Map<string,Buffer>();private renders=0;private children=new Set<ReturnType<typeof spawn>>();private streams=new Set<fs.ReadStream>();
 constructor(private configFile:string,private options:{roots?:Root[];ffmpeg?:string;convert?:string;placeholder:Buffer}){
  try{const v=JSON.parse(fs.readFileSync(configFile,'utf8'));if(v.source==='photos'||v.source==='nas'){if(typeof v.enabled==='boolean'&&typeof v.deviceId==='string'&&Number.isInteger(v.intervalMs)&&v.intervalMs>=3000&&v.intervalMs<=60000&&typeof v.folder==='string'&&Array.isArray(v.files)&&v.files.length<=64&&v.files.every((x:unknown)=>typeof x==='string')&&/^[a-f0-9]{24}$/.test(v.revision))this.value=v;}}catch{}
 }
 roots():Root[]{
  if(this.options.roots)return this.options.roots;
  const result:Root[]=[];try{for(const d of fs.readdirSync('/volume1',{withFileTypes:true})){if(d.isDirectory()&&!hidden(d.name)&&d.name!=='homes')result.push({label:d.name,path:'/volume1/'+d.name});}}catch{}
  try{const home=fs.realpathSync(os.homedir());if(home.startsWith('/volume1/homes/')&&home.split('/').length===4)result.push({label:'我的文件',path:home});}catch{}
  return result;
 }
 private resolve(file:string,directory=false){
  const target=path.resolve(file),root=this.roots().find(r=>target===r.path||target.startsWith(r.path+path.sep));if(!root)throw Error('文件超出 NAS 选择范围');
  let cursor=root.path;const rest=path.relative(root.path,target).split(path.sep).filter(Boolean);
  if(fs.lstatSync(cursor).isSymbolicLink())throw Error('不支持符号链接');
  for(const part of rest){if(hidden(part))throw Error('不支持系统目录');cursor=path.join(cursor,part);if(fs.lstatSync(cursor).isSymbolicLink())throw Error('不支持符号链接');}
  if(fs.realpathSync(target)!==target)throw Error('文件路径发生变化');const st=fs.statSync(target);if(directory?!st.isDirectory():!st.isFile())throw Error('请选择'+(directory?'文件夹':'文件'));return {target,st};
 }
 browse(body:Record<string,unknown>){
  if(Object.keys(body).some(k=>!['location','offset','kind'].includes(k))||body.kind!==undefined&&!['folder','video','audio'].includes(String(body.kind)))throw Error('文件选择请求无效');
  const offset=Number(body.offset||0);if(!Number.isSafeInteger(offset)||offset<0||offset>100000)throw Error('分页无效');
  if(!body.location)return {label:'NAS',location:'',parent:'',entries:this.roots().map(r=>({key:key(r.path),name:r.label,kind:'folder'})),offset:0,hasMore:false};
  const {target}=this.resolve(decode(body.location),true),root=this.roots().find(r=>target===r.path||target.startsWith(r.path+'/'))!;
  const entries=fs.readdirSync(target,{withFileTypes:true}).filter(d=>!hidden(d.name)&&!d.isSymbolicLink()&&(d.isDirectory()||d.isFile()&&(body.kind==='video'?video.has(path.extname(d.name).toLowerCase()):body.kind==='audio'?audio.has(path.extname(d.name).toLowerCase()):false))).sort((a,b)=>Number(b.isDirectory())-Number(a.isDirectory())||a.name.localeCompare(b.name,'zh-Hans-CN'));
  return {label:target===root.path?root.label:path.basename(target),location:key(target),parent:target===root.path?'':key(path.dirname(target)),entries:entries.slice(offset,offset+100).map(d=>({key:key(path.join(target,d.name)),name:d.name,kind:d.isDirectory()?'folder':body.kind})),offset,hasMore:entries.length>offset+100};
 }
 settings(){return {...this.value,folder:this.value.folder?{key:key(this.value.folder),name:path.basename(this.value.folder)}:null,files:this.value.files.map(p=>({key:key(p),name:path.basename(p),kind:audio.has(path.extname(p).toLowerCase())?'audio':'video'})),configured:!!this.value.folder||this.value.files.length>0};}
 source(){return this.value.source;}
 configure(body:Record<string,unknown>,knownIds:string[]){
  if(Object.keys(body).some(k=>!['source','enabled','deviceId','intervalMs','folder','files','recursive'].includes(k))||!['nas','photos'].includes(String(body.source)))throw Error('媒体来源无效');
  if(typeof body.enabled!=='boolean'||typeof body.deviceId!=='string'||!knownIds.includes(body.deviceId)||!Number.isInteger(body.intervalMs)||Number(body.intervalMs)<3000||Number(body.intervalMs)>60000)throw Error('请选择设备和 3–60 秒间隔');
  const source=body.source as Source['source'];let folder='',files:string[]=[];
  if(source==='nas'){
   if(body.folder){folder=this.resolve(decode(body.folder),true).target;}
   if(!Array.isArray(body.files)||body.files.length>64)throw Error('最多选择 64 个视频或音乐文件');
   files=[...new Set(body.files.map(v=>{const p=this.resolve(decode(v)).target;if(!video.has(path.extname(p).toLowerCase())&&!audio.has(path.extname(p).toLowerCase()))throw Error('请选择 MP4、MOV 或音乐文件');return p;}))];
   if(body.enabled&&!folder&&!files.length)throw Error('请选择照片文件夹或媒体文件');
  }else {folder=this.value.folder;files=this.value.files;}
  const next:Source={source,enabled:body.enabled,deviceId:body.deviceId,intervalMs:Number(body.intervalMs),folder,files,recursive:body.recursive!==false,revision:randomBytes(12).toString('hex')};
  fs.writeFileSync(this.configFile+'.new',JSON.stringify(next)+'\n',{mode:0o600});fs.renameSync(this.configFile+'.new',this.configFile);this.close();this.value=next;this.indexedAt=0;this.items.clear();this.previews.clear();return this.settings();
 }
 allowed(id:string){return this.value.source==='nas'&&this.value.enabled&&this.value.deviceId===id;}
 private async index(){
  if(this.indexing)return this.indexing;if(Date.now()-this.indexedAt<10000)return;
  const config=this.value;
  this.indexing=(async()=>{const paths:string[]=[];let inspected=0;const scan=async(dir:string,depth:number)=>{
   if(depth>10||paths.length>=5000||inspected>=20000)return;const {target}=this.resolve(dir,true);const entries=fs.readdirSync(target,{withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name,'zh-Hans-CN'));
   for(const d of entries){if(++inspected>20000||paths.length>=5000)break;if(hidden(d.name)||d.isSymbolicLink())continue;const p=path.join(dir,d.name);if(d.isFile()&&photo.has(path.extname(d.name).toLowerCase()))paths.push(p);else if(d.isDirectory()&&config.recursive)await scan(p,depth+1);}await new Promise<void>(r=>setImmediate(r));
  };if(config.folder)await scan(config.folder,0);paths.push(...config.files);
   const rows:Item[]=[];for(const file of [...new Set(paths)]){try{const {st}=this.resolve(file);if(st.size<=0)continue;const ext=path.extname(file).toLowerCase();const id=String(parseInt(hash(file).slice(0,9),16));rows.push({id,file,size:st.size,mtime:st.mtimeMs,ino:st.ino,kind:photo.has(ext)?'photo':audio.has(ext)?'audio':'video'});}catch{}}
   if(config!==this.value)throw Error('媒体选择已更新，请刷新');const revision=hash(config.revision+rows.map(r=>r.id+':'+r.size+':'+r.mtime).join('|')).slice(0,24);if(revision!==this.currentRevision)this.previews.clear();this.currentRevision=revision;this.listed=rows;this.items=new Map(rows.map(r=>[r.id,r]));this.indexedAt=Date.now();
  })();try{await this.indexing}finally{this.indexing=undefined}
 }
 async manifest(id:string,offset:number){if(!this.allowed(id))return {enabled:false,items:[]};if(!Number.isInteger(offset)||offset<0||offset>100000)throw Error('分页无效');await this.index();if(!this.allowed(id))return {enabled:false,items:[]};
  return {enabled:true,source:'nas',revision:this.currentRevision,albumName:this.value.folder?path.basename(this.value.folder):'NAS 媒体',intervalMs:this.value.intervalMs,offset,hasMore:this.listed.length>offset+24,items:this.listed.slice(offset,offset+24).map(r=>({id:r.id,kind:r.kind,title:path.basename(r.file),streamable:r.kind!=='photo',preview:'/api/media/item/'+r.id+'/preview?revision='+this.currentRevision,playback:r.kind!=='photo'?'/api/media/item/'+r.id+'/video?revision='+this.currentRevision:undefined}))};
 }
 private async item(id:string,itemId:string,revision:string){if(!this.allowed(id)||revision!==this.currentRevision)throw Error('媒体选择已更新，请刷新');const item=this.items.get(itemId);if(!item)throw Error('媒体未被选中');const {st}=this.resolve(item.file);if(st.size!==item.size||st.mtimeMs!==item.mtime||st.ino!==item.ino){this.indexedAt=0;throw Error('文件已更新，请刷新');}return item;}
 private ffmpeg(){return this.options.ffmpeg||['/usr/bin/ffmpeg','/bin/ffmpeg','/var/packages/ffmpeg/target/bin/ffmpeg','/var/packages/ffmpeg7/target/bin/ffmpeg','/var/packages/SynologyPhotos/target/usr/bin/ffmpeg','/var/packages/SynologyPhotos/target/bin/ffmpeg','/var/packages/CodecPack/target/bin/ffmpeg'].find(p=>{try{fs.accessSync(p,fs.constants.X_OK);return true}catch{return false}});}
 async preview(id:string,itemId:string,revision:string){const item=await this.item(id,itemId,revision);if(this.previews.has(itemId))return this.previews.get(itemId)!;if(item.kind==='audio')return this.options.placeholder;
  // Use an existing, selected-file-specific NAS thumbnail when available.
  for(const name of ['SYNOPHOTO_THUMB_XL.jpg','SYNOPHOTO_THUMB_L.jpg']){try{const p=path.join(path.dirname(item.file),'@eaDir',path.basename(item.file),name);const real=fs.realpathSync(p),st=fs.statSync(p);if(real===p&&st.isFile()&&st.size>0&&st.size<=4*1024*1024){const b=fs.readFileSync(p);if(b[0]===255&&b[1]===216){await this.item(id,itemId,revision);return b;}}}catch{}}
  const convert=item.kind==='photo'?(this.options.convert||['/usr/bin/convert','/bin/convert'].find(p=>{try{fs.accessSync(p,fs.constants.X_OK);return true}catch{return false}})):undefined;const codec=({'.jpg':'jpeg','.jpeg':'jpeg','.png':'png','.webp':'webp','.bmp':'bmp'} as Record<string,string>)[path.extname(item.file).toLowerCase()];const useConvert=!!convert&&!!codec;const tool=useConvert?convert:this.ffmpeg();let data:Buffer;if(tool){
   if(this.renders>=2)throw Error('预览正在准备，请重试');this.renders++;
   try{data=await new Promise<Buffer>((resolve,reject)=>{const args=useConvert?['-limit','memory','64MiB','-limit','map','128MiB','-limit','disk','0','-limit','thread','1','-define','jpeg:size=1440x1440',codec+':-','-auto-orient','-thumbnail','720x720>','-strip','-quality','85','jpeg:-']:['-nostdin','-v','error',...(item.kind==='video'?['-ss','0.2']:[]),'-i',item.file,'-frames:v','1','-vf','scale=720:720:force_original_aspect_ratio=decrease','-q:v','3','-f','image2pipe','pipe:1'];const child=spawn(tool,args,{stdio:[useConvert?'pipe':'ignore','pipe','ignore']});let input:fs.ReadStream|undefined;if(useConvert){input=fs.createReadStream(item.file);input.on('error',()=>child.kill());child.stdin?.on('error',()=>input?.destroy());input.pipe(child.stdin!);}this.children.add(child);let n=0;const chunks:Buffer[]=[];const timer=setTimeout(()=>{child.kill();reject(Error('预览准备超时'));},12000);child.stdout!.on('data',b=>{if((n+=b.length)>4*1024*1024){child.kill();reject(Error('预览过大'));}else chunks.push(b)});child.on('error',()=>reject(Error('预览工具不可用')));child.on('close',code=>{input?.destroy();clearTimeout(timer);this.children.delete(child);const b=Buffer.concat(chunks);if(code===0&&b[0]===255&&b[1]===216)resolve(b);else reject(Error('预览不可用'));});});}catch(e){if(item.kind==='video')data=this.options.placeholder;else if(item.size<=4*1024*1024){data=fs.readFileSync(item.file);if(!smallRaster(data))throw e;}else throw e;}finally{this.renders--;}
  }else if(item.kind==='video')data=this.options.placeholder;else if(item.size<=4*1024*1024){data=fs.readFileSync(item.file);if(!smallRaster(data))throw Error('NAS 需要启用照片预览工具');}else throw Error('NAS 需要启用照片预览工具');
  await this.item(id,itemId,revision);this.previews.set(itemId,data);while(this.previews.size>8)this.previews.delete(this.previews.keys().next().value!);return data;
 }
 async stream(id:string,itemId:string,revision:string,req:IncomingMessage,res:ServerResponse){const item=await this.item(id,itemId,revision);if(item.kind==='photo')throw Error('请选择视频或音乐');let range;
  try{range=parseRange(req.headers.range,item.size);}catch{res.writeHead(416,{'Content-Range':'bytes */'+item.size,'Content-Length':'0'});res.end();return;}
  const fd=fs.openSync(item.file,fs.constants.O_RDONLY|fs.constants.O_NOFOLLOW);let stream:fs.ReadStream|undefined;
  try{const actual=fs.fstatSync(fd);const opened=process.platform==='linux'?fs.realpathSync('/proc/self/fd/'+fd):fs.realpathSync(item.file);if(opened!==item.file||actual.ino!==item.ino||actual.size!==item.size||actual.mtimeMs!==item.mtime)throw Error('文件已变化');
   const type=item.kind==='video'?({'.mov':'video/quicktime','.mkv':'video/x-matroska','.webm':'video/webm','.avi':'video/x-msvideo','.ts':'video/mp2t'}[path.extname(item.file).toLowerCase()]||'video/mp4'):({'.mp3':'audio/mpeg','.m4a':'audio/mp4','.wav':'audio/wav','.flac':'audio/flac','.ogg':'audio/ogg'}[path.extname(item.file).toLowerCase()]||'application/octet-stream');
   res.writeHead(range.status,{'Content-Type':type,'Content-Length':range.end-range.start+1,'Accept-Ranges':'bytes','Cache-Control':'private, no-store',...(range.status===206?{'Content-Range':`bytes ${range.start}-${range.end}/${item.size}`}:{})});
   if(req.method==='HEAD'){fs.closeSync(fd);res.end();return;}
   stream=fs.createReadStream(item.file,{fd,autoClose:true,start:range.start,end:range.end,highWaterMark:65536});this.streams.add(stream);stream.on('close',()=>this.streams.delete(stream!));stream.on('error',()=>res.destroy());res.on('close',()=>stream?.destroy());stream.pipe(res);
  }catch(e){if(!stream)fs.closeSync(fd);throw e;}
 }
 close(){for(const c of this.children)c.kill();for(const s of this.streams)s.destroy();}
}
