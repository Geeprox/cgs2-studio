// SPDX-License-Identifier: MIT
#include <assert.h>
#include "../device/lan_origin.h"
int main(void){
 const char *good[]={"https://10.0.0.1:443","https://172.16.0.1:6080","https://172.31.255.254:65535","https://192.168.0.1:1"};
 const char *bad[]={"http://10.0.0.1:443","https://127.0.0.1:443","https://8.8.8.8:443","https://172.32.0.1:443","https://10.0.0.1:0","https://10.0.0.1:65536","https://010.0.0.1:443","https://10.0.0.1:0443","https://10.0.0.1:443/","https://10.0.0.1:443\r\nHeader: x","https://user@10.0.0.1:443","https://10.0.0.999:443","https://nas.local:443","","https://"};
 for(unsigned i=0;i<sizeof(good)/sizeof(*good);i++)assert(valid_origin(good[i]));
 for(unsigned i=0;i<sizeof(bad)/sizeof(*bad);i++)assert(!valid_origin(bad[i]));
}
