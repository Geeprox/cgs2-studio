// SPDX-License-Identifier: MIT
// Read only the pairing identifier, never EXIF location, dates or captions.
import fs from 'node:fs';
const uuid=(s:string)=>/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(s)?s.toLowerCase():'';
export function appleStillIdentifier(b:Buffer){
 const at=b.indexOf(Buffer.from('Apple iOS\0'));if(at<0||at+16>b.length)return '';
 const order=b.toString('ascii',at+12,at+14);if(order!=='MM'&&order!=='II')return '';
 const u16=(p:number)=>order==='MM'?b.readUInt16BE(p):b.readUInt16LE(p),u32=(p:number)=>order==='MM'?b.readUInt32BE(p):b.readUInt32LE(p);
 const count=u16(at+14);if(count>256||at+16+count*12>b.length)return '';
 for(let i=0;i<count;i++){const p=at+16+i*12;if(u16(p)!==17||u16(p+2)!==2)continue;const n=u32(p+4),offset=at+u32(p+8);if(n<36||n>64||offset<at||offset+n>b.length)return '';return uuid(b.toString('utf8',offset,offset+n).replace(/\0+$/,''));}
 return '';
}
function boxes(b:Buffer,start=0,end=b.length){const out:{type:string;tag:number;start:number;end:number}[]=[];for(let p=start;p+8<=end;){const size=b.readUInt32BE(p);if(size<8||p+size>end)break;out.push({type:b.toString('ascii',p+4,p+8),tag:b.readUInt32BE(p+4),start:p+8,end:p+size});p+=size;if(out.length>4096)break;}return out;}
export function quickTimeIdentifier(b:Buffer):string{
 const walk=(start:number,end:number,depth:number):string=>{if(depth>5)return '';const rows=boxes(b,start,end);const keys=rows.find(x=>x.type==='keys'),list=rows.find(x=>x.type==='ilst');
  if(keys&&list&&keys.start+8<=keys.end){const n=b.readUInt32BE(keys.start+4);let p=keys.start+8,index=0;if(n>256)return '';
   for(let i=1;i<=n&&p+8<=keys.end;i++){const size=b.readUInt32BE(p);if(size<8||p+size>keys.end)return '';if(b.toString('utf8',p+8,p+size)==='com.apple.quicktime.content.identifier')index=i;p+=size;}
   const item=boxes(b,list.start,list.end).find(x=>x.tag===index);if(index&&item){const data=boxes(b,item.start,item.end).find(x=>x.type==='data');if(data&&data.end-data.start>=8&&data.end-data.start<=80&&b.readUInt32BE(data.start)===1)return uuid(b.toString('utf8',data.start+8,data.end).replace(/\0+$/,''));}
  }
  for(const row of rows)if(['moov','udta','meta'].includes(row.type)){const skip=row.type==='meta'&&row.start+4<=row.end&&b.readUInt32BE(row.start)===0?4:0;const value=walk(row.start+skip,row.end,depth+1);if(value)return value;}return '';
 };return walk(0,b.length,0);
}
export function pairingIdentifier(file:string,movie=false){
 const fd=fs.openSync(file,fs.constants.O_RDONLY|fs.constants.O_NOFOLLOW);
 try{if(process.platform==='linux'&&fs.realpathSync('/proc/self/fd/'+fd)!==file)return '';const st=fs.fstatSync(fd);if(!st.isFile())return '';
  const read=(at:number,n:number)=>{const b=Buffer.alloc(n);fs.readSync(fd,b,0,n,at);return b;};
  if(!movie){const n=Math.min(st.size,2*1024*1024);const id=appleStillIdentifier(read(0,n));return id||(st.size>n?appleStillIdentifier(read(Math.max(0,st.size-n),n)):'');}
  let at=0;for(let n=0;n<1024&&at+8<=st.size;n++){const h=read(at,16);let size=h.readUInt32BE(0),header=8;if(size===1){const big=h.readBigUInt64BE(8);if(big>BigInt(Number.MAX_SAFE_INTEGER))return '';size=Number(big);header=16;}if(size===0)size=st.size-at;if(size<header||at+size>st.size)return '';if(h.toString('ascii',4,8)==='moov'&&size<=4*1024*1024){const data=read(at+header,size-header);return quickTimeIdentifier(data);}at+=size;}return '';
 }finally{fs.closeSync(fd);}
}
