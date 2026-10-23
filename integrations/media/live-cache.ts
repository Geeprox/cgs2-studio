// SPDX-License-Identifier: MIT
import fs from 'node:fs';import path from 'node:path';import {createHash,randomBytes} from 'node:crypto';import {spawn} from 'node:child_process';
export class LiveCache{
 private pending=new Map<string,Promise<string>>();private children=new Set<ReturnType<typeof spawn>>();private generation=0;
 constructor(private dir:string,private ffmpeg:()=>string|undefined){}
 async prepare(file:string,signature:string){
  const id=createHash('sha256').update(file+'|'+signature).digest('hex'),target=path.join(this.dir,id+'.mp4');
  fs.mkdirSync(this.dir,{recursive:true,mode:0o700});if(fs.lstatSync(this.dir).isSymbolicLink())throw Error('动态缓存路径无效');
  try{const st=fs.lstatSync(target);if(st.isFile()&&!st.isSymbolicLink()&&st.size>0&&st.size<=32*1024*1024){fs.utimesSync(target,new Date(),new Date());return target;}}catch{}
  if(this.pending.has(id))return this.pending.get(id)!;if(this.pending.size>=1)throw Error('动态预览正在准备，请稍后重试');
  const tool=this.ffmpeg();if(!tool)throw Error('NAS 需要支持 HEVC 解码与 libx264/AAC 编码的 FFmpeg');
  const generation=this.generation,work=target+'.'+randomBytes(8).toString('hex')+'.tmp.mp4';
  const task=(async()=>{
   const fd=fs.openSync(file,fs.constants.O_RDONLY|fs.constants.O_NOFOLLOW);
   try{if(process.platform==='linux'&&fs.realpathSync('/proc/self/fd/'+fd)!==file)throw Error('动态文件已变化');
    await new Promise<void>((resolve,reject)=>{
     const child=spawn(tool,['-nostdin','-hide_banner','-loglevel','error','-threads','1','-i',process.platform==='linux'?'/proc/self/fd/3':'/dev/fd/3','-t','15','-map','0:v:0','-map','0:a:0?','-sn','-dn','-vf','scale=720:720:force_original_aspect_ratio=decrease:force_divisible_by=2,setsar=1','-r','30','-c:v','libx264','-threads','1','-profile:v','baseline','-level','3.1','-preset','veryfast','-crf','24','-pix_fmt','yuv420p','-c:a','aac','-ac','2','-ar','44100','-b:a','96k','-movflags','+faststart','-map_metadata','-1','-fs','33554432','-y',work],{stdio:['ignore','ignore','ignore',fd]});
     this.children.add(child);const timer=setTimeout(()=>{child.kill('SIGKILL');reject(Error('动态预览准备超时'));},45000);
     child.on('error',()=>{clearTimeout(timer);this.children.delete(child);reject(Error('动态预览工具不可用'));});
     child.on('close',code=>{clearTimeout(timer);this.children.delete(child);code===0?resolve():reject(Error('动态转换失败，请配置兼容 FFmpeg'));});
    });
    if(generation!==this.generation)throw Error('媒体选择已更新');const st=fs.lstatSync(work);if(!st.isFile()||st.size<=0||st.size>32*1024*1024)throw Error('动态预览无效');fs.chmodSync(work,0o600);fs.renameSync(work,target);
    const cache=fs.readdirSync(this.dir).filter(n=>/^[a-f0-9]{64}\.mp4$/.test(n)).map(n=>({file:path.join(this.dir,n),mtime:fs.lstatSync(path.join(this.dir,n)).mtimeMs})).sort((a,b)=>b.mtime-a.mtime);
    for(const old of cache.slice(8))fs.unlinkSync(old.file);return target;
   }finally{fs.closeSync(fd);try{fs.unlinkSync(work);}catch{}}
  })();this.pending.set(id,task);try{return await task}finally{this.pending.delete(id)}
 }
 close(){this.generation++;for(const child of this.children)child.kill('SIGKILL');this.children.clear();}
}
