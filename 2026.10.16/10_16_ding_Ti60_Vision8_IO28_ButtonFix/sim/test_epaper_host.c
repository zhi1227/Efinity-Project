#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include "../firmware/epaper.h"
static uint32_t now, app, busy_until, tx_until;
static unsigned fault, count, refresh, resets, steps;
static int active, tx_active;
uint32_t epd_read(uint32_t offset) {
 if(offset==12) return now;
 assert(offset==0);
 if(active && (int32_t)(now-busy_until)>=0 && fault!=3) active=0;
 if(tx_active && (int32_t)(now-tx_until)>=0) tx_active=0;
 return ((fault==1 || active)?2:0) | ((fault==4)?4:0) | ((fault==5 || tx_active)?1:0);
}
void epd_write(uint32_t offset,uint32_t value) {
 if(offset==16) {app=value;return;}
 if(offset==4) {if(!value) ++resets;return;}
 if(offset==0) return;
 assert(offset==8);
 ++count;tx_until=now+1;tx_active=1;
 if(value==0x20) {++refresh;if(fault!=2){active=1;busy_until=now+100;}}
}
static void run(unsigned f,uint32_t start,unsigned expected) {
 fault=f;now=start;app=count=refresh=resets=steps=0;active=tx_active=0;
 epaper_start();
 while(app!=3 && !(app&128) && steps<1000000) {epaper_service();++steps;++now;}
 assert(app==expected);
 if(!f) {assert(count==30033);assert(refresh==1);assert(resets==1);}
 unsigned saved=count;
 for(unsigned i=0;i<1000;++i){++now;epaper_service();}
 assert(count==saved);
}
int main(void) {
 run(0,0,3);run(0,0xfffffff0u,3);
 run(1,0,0x81);run(2,0,0x82);run(3,0,0x81);
 run(4,0,0x83);run(5,0,0x84);
 puts("PASS: firmware normal/wraparound, stuck BUSY, missing BUSY, overflow, TX timeout; terminal states remain idle");
 return 0;
}
