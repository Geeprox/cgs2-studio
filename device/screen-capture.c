// SPDX-License-Identifier: MIT
// Read active CGS2 DRM scanout. Never acquire master, set modes or write pixels.
typedef unsigned long U;typedef long I;typedef unsigned int u32;
static I sc(I n,I a,I b,I c,I d,I e,I f){register I x8 __asm__("x8")=n;register I x0 __asm__("x0")=a;register I x1 __asm__("x1")=b;register I x2 __asm__("x2")=c;register I x3 __asm__("x3")=d;register I x4 __asm__("x4")=e;register I x5 __asm__("x5")=f;__asm__ volatile("svc #0":"+r"(x0):"r"(x8),"r"(x1),"r"(x2),"r"(x3),"r"(x4),"r"(x5):"memory","cc");return x0;}
#define S(n,a,b,c,d,e,f) sc(n,(I)(a),(I)(b),(I)(c),(I)(d),(I)(e),(I)(f))
static int all(int fd,const char*p,U n){while(n){I w=S(64,fd,p,n,0,0,0);if(w<=0)return 0;p+=w;n-=w;}return 1;}
void _start(void){
 I fd=S(56,-100,"/dev/dri/card0",2,0,0,0);if(fd<0)S(93,2,0,0,0,0,0);
 // Resources then active CRTC: no master, mode changes or writes to buffers.
 u32 crtcs[16];struct {U fb,crtc,conn,enc;u32 nf,nc,nn,ne,minw,maxw,minh,maxh;} r={0,(U)crtcs,0,0,0,16,0,0,0,0,0,0};
 if(S(29,fd,0xc04064a0,&r,0,0,0)<0||r.nc>16)S(93,3,0,0,0,0,0);
 struct {U conns;u32 count,id,fb,x,y,gamma,valid;char mode[68];} c={0};
 u32 fb=0;for(u32 i=0;i<r.nc;i++){c.id=crtcs[i];if(S(29,fd,0xc06864a1,&c,0,0,0)>=0&&c.fb){fb=c.fb;break;}}
 if(!fb)S(93,4,0,0,0,0,0);
 struct {u32 id,w,h,pitch,bpp,depth,handle;} info={fb,0,0,0,0,0,0};
 if(S(29,fd,0xc01c64ad,&info,0,0,0)<0||info.w!=720||info.h!=720||info.bpp!=32||info.pitch<2880||info.pitch>8192)S(93,5,0,0,0,0,0);
 struct {u32 handle,pad;U offset;} map={info.handle,0,0};
 if(S(29,fd,0xc01064b3,&map,0,0,0)<0)S(93,6,0,0,0,0,0);
 U n=info.pitch*info.h;I buf=S(222,0,n,1,1,fd,map.offset);if(buf<0)S(93,7,0,0,0,0,0);
 u32 header[4]={info.w,info.h,info.pitch,info.bpp};if(!all(1,(char*)header,16)||!all(1,(char*)buf,n))S(93,8,0,0,0,0,0);
 S(215,buf,n,0,0,0,0);S(57,fd,0,0,0,0,0);S(93,0,0,0,0,0,0);
}
