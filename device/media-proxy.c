// SPDX-License-Identifier: MIT
#include "lan_origin.h"
/* Tiny Linux/aarch64 loopback relay. No libc, TLS or decoder implementation.
 * An owned curl child verifies the existing NAS CA and reads existing headers.
 * Only numeric selected item IDs/revisions and one bounded byte range pass.
 */
typedef unsigned long U; typedef long I;
static I sc(I n,I a,I b,I c,I d,I e,I f){register I x8 __asm__("x8")=n;register I x0 __asm__("x0")=a;register I x1 __asm__("x1")=b;register I x2 __asm__("x2")=c;register I x3 __asm__("x3")=d;register I x4 __asm__("x4")=e;register I x5 __asm__("x5")=f;__asm__ volatile("svc #0":"+r"(x0):"r"(x8),"r"(x1),"r"(x2),"r"(x3),"r"(x4),"r"(x5):"memory","cc");return x0;}
#define S(n,a,b,c,d,e,f) sc(n,(I)(a),(I)(b),(I)(c),(I)(d),(I)(e),(I)(f))
static U len(const char*s){U n=0;while(s[n])n++;return n;}
static int eq(const char*a,const char*b){while(*a&&*a==*b){a++;b++;}return *a==*b;}
static int pre(const char*a,const char*b){while(*b)if(*a++!=*b++)return 0;return 1;}
static void copy(char*a,const char*b){while((*a++=*b++));}
static void add(char*a,const char*b){copy(a+len(a),b);}
static int writeall(int fd,const char*p,I n){while(n>0){I r=S(64,fd,p,n,0,0,0);if(r<=0)return 0;p+=r;n-=r;}return 1;}
static void fail(int fd){const char*s="HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";writeall(fd,s,len(s));}
static int lower(char a){return a>='A'&&a<='Z'?a+32:a;}
static int hpre(const char*a,const char*b){while(*b)if(lower(*a++)!=*b++)return 0;return 1;}
static void serve(int fd){
 char request[8193],id[13],rev[25],range[80],url[256],origin[96],origin_header[112];I n=0;int done=0,head=0;
 struct {I seconds,microseconds;} timeout={5,0};S(208,fd,1,20,&timeout,sizeof(timeout),0);
 while(n<8192&&!done){I r=S(63,fd,request+n,8192-n,0,0,0);if(r<=0)return;n+=r;request[n]=0;for(I i=3;i<n;i++)if(request[i-3]=='\r'&&request[i-2]=='\n'&&request[i-1]=='\r'&&request[i]=='\n'){done=1;request[i+1]=0;break;}}
 if(!done){fail(fd);return;}char*p=request;if(pre(p,"GET /media/"))p+=11;else if(pre(p,"HEAD /media/")){p+=12;head=1;}else{fail(fd);return;}
 int k=0;while(*p>='0'&&*p<='9'&&k<12)id[k++]=*p++;id[k]=0;if(!k||!pre(p,"?revision=")){fail(fd);return;}p+=10;
 for(k=0;k<24;k++){if(!((*p>='0'&&*p<='9')||(*p>='a'&&*p<='f'))){fail(fd);return;}rev[k]=*p++;}rev[24]=0;
 if(!pre(p," HTTP/1.1\r\n")&&!pre(p," HTTP/1.0\r\n")){fail(fd);return;}
 range[0]=0;int host=0;for(p=request;*p;p++){if(p==request||p[-1]!='\n')continue;
  if(hpre(p,"host:")){p+=5;while(*p==' ')p++;if(pre(p,"127.0.0.1:6097\r\n"))host=1;else{fail(fd);return;}}
  if(hpre(p,"range:")){if(range[0]){fail(fd);return;}p+=6;while(*p==' ')p++;if(!pre(p,"bytes=")){fail(fd);return;}copy(range,"Range: ");int digits=0,dash=0;for(k=7;*p&&*p!='\r'&&k<76;p++,k++){char c=*p;if(c=='-'){if(dash++){fail(fd);return;}}else if(c>='0'&&c<='9')digits++;else if(k<13&&c=="bytes="[k-7]){}else{fail(fd);return;}range[k]=c;}range[k]=0;if(*p!='\r'||!digits||dash!=1){fail(fd);return;}}
 }
 if(!host){fail(fd);return;}
 const char *ca="/userdata/cgs2-media/ca.pem",*auth="@/userdata/cgs2-media/auth-header";
 I conf=S(56,-100,"/userdata/cgs2-media/origin",0x20000,0,0,0);if(conf==-2){ca="/userdata/cgs2-micro/ca.pem";auth="@/userdata/cgs2-micro/auth-header";conf=S(56,-100,"/userdata/cgs2-micro/origin",0x20000,0,0,0);}
 if(conf<0){fail(fd);return;}I size=S(63,conf,origin,95,0,0,0);S(57,conf,0,0,0,0,0);if(size<=0||size>=95){fail(fd);return;}while(size>0&&(origin[size-1]=='\n'||origin[size-1]=='\r'))size--;origin[size]=0;
 if(!valid_origin(origin)){fail(fd);return;}
 copy(origin_header,"Origin: ");add(origin_header,origin);
 copy(url,origin);add(url,"/api/media/item/");add(url,id);add(url,"/video?revision=");add(url,rev);
 int pp[2];if(S(59,pp,0,0,0,0,0)<0){fail(fd);return;}
 I child=S(220,17,0,0,0,0,0);if(child==0){
  S(57,pp[0],0,0,0,0,0);S(24,pp[1],1,0,0,0,0);S(57,pp[1],0,0,0,0,0);S(57,fd,0,0,0,0,0);
  I null=S(56,-100,"/dev/null",1,0,0,0);S(24,null,2,0,0,0,0);S(57,null,0,0,0,0,0);
  char*args[32];int a=0;args[a++]="curl";args[a++]="-q";args[a++]="--silent";args[a++]="--raw";args[a++]="--include";args[a++]="--http1.1";args[a++]="--noproxy";args[a++]="*";args[a++]="--proto";args[a++]="=https";args[a++]="--cacert";args[a++]=(char*)ca;args[a++]="--header";args[a++]=(char*)auth;args[a++]="--header";args[a++]=origin_header;args[a++]="--connect-timeout";args[a++]="4";args[a++]="--speed-time";args[a++]="20";args[a++]="--speed-limit";args[a++]="1";args[a++]="--max-time";args[a++]="7200";
  if(head)args[a++]="--head";if(range[0]){args[a++]="--header";args[a++]=range;}args[a++]=url;args[a]=0;char*env[]={"PATH=/usr/bin:/bin",0};S(221,"/usr/bin/curl",args,env,0,0,0);S(93,127,0,0,0,0,0);
 }
 S(57,pp[1],0,0,0,0,0);if(child<0){S(57,pp[0],0,0,0,0,0);fail(fd);return;}
 char buffer[32768];I sent=0;for(;;){I r=S(63,pp[0],buffer,sizeof(buffer),0,0,0);if(r<=0)break;if(!writeall(fd,buffer,r))break;sent+=r;}
 S(57,pp[0],0,0,0,0,0);S(129,child,15,0,0,0,0);S(260,child,0,0,0,0,0);if(!sent)fail(fd);
}
void _start(void){
 struct {U handler,flags,restorer,mask;} ignore={1,0,0,0};S(134,13,&ignore,0,8,0,0);
 I listener=S(198,2,1,0,0,0,0);if(listener<0)S(93,2,0,0,0,0,0);int reuse=1;S(208,listener,1,2,&reuse,4,0);
 struct {unsigned short family,port;unsigned char ip[4];char zero[8];} addr={2,0xd117,{127,0,0,1},{0}}; // htons(6097)
 if(S(200,listener,&addr,sizeof(addr),0,0,0)<0||S(201,listener,4,0,0,0,0)<0)S(93,3,0,0,0,0,0);
 int active=0;for(;;){while(S(260,-1,0,1,0,0,0)>0)if(active)active--;I fd=S(202,listener,0,0,0,0,0);if(fd<0)continue;while(S(260,-1,0,1,0,0,0)>0)if(active)active--;
  if(active>=3){fail(fd);S(57,fd,0,0,0,0,0);continue;}I child=S(220,17,0,0,0,0,0);if(child==0){S(57,listener,0,0,0,0,0);serve(fd);S(57,fd,0,0,0,0,0);S(93,0,0,0,0,0,0);}if(child>0)active++;S(57,fd,0,0,0,0,0);
 }
}
