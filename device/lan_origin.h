/* SPDX-License-Identifier: MIT */
/* Canonical HTTPS RFC1918 IPv4 + explicit port, with no path or user info. */
static int valid_origin(const char *s) {
 const char *p="https://";while(*p)if(*s++!=*p++)return 0;
 int ip[4];
 for(int i=0;i<4;i++){
  int n=0,digits=0;const char *first=s;
  while(*s>='0'&&*s<='9'){n=n*10+(*s++-'0');if(++digits>3||n>255)return 0;}
  if(!digits||(digits>1&&*first=='0'))return 0;
  ip[i]=n;if(i<3&&*s++!='.')return 0;
 }
 if(*s++!=':')return 0;
 int port=0,digits=0;if(*s=='0')return 0;
 while(*s>='0'&&*s<='9'){port=port*10+(*s++-'0');if(++digits>5||port>65535)return 0;}
 return !*s&&digits&&port>0&&(ip[0]==10||(ip[0]==192&&ip[1]==168)||(ip[0]==172&&ip[1]>=16&&ip[1]<=31));
}
