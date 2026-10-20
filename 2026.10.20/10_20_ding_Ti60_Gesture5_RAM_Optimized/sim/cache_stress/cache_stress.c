#include <stdint.h>
static volatile uint32_t data[1024];
#define RESULT (*(volatile uint32_t *)0xF8100008u)
static void fail(uint32_t code){RESULT=0xbad00000u|code;for(;;){}}
__attribute__((noinline,aligned(1024))) static uint32_t f0(uint32_t x){return x*3u+5u;}
__attribute__((noinline,aligned(1024))) static uint32_t f1(uint32_t x){return (x^0xa5a55a5au)+7u;}
__attribute__((noinline,aligned(1024))) static uint32_t f2(uint32_t x){return (x>>3)+(x<<5);}
__attribute__((noinline,aligned(1024))) static uint32_t f3(uint32_t x){return x*17u-11u;}
int main(void){
 for(uint32_t i=0;i<1024;i++)data[i]=0x12340000u+i;
 for(uint32_t j=0;j<16;j++)for(uint32_t k=0;k<4;k++){
  uint32_t i=j+k*256;if(data[i]!=0x12340000u+i)fail(1);
  volatile uint8_t *p=(volatile uint8_t *)&data[i];p[1]=0xabu;
  if(data[i]!=((0x12340000u+i)&0xffff00ffu|0xab00u))fail(2);
  volatile uint16_t *h=(volatile uint16_t *)&data[i];h[1]=0xcdefu;
  if(data[i]!=(0xcdefab00u|(i&255u)))fail(3);
 }
 for(uint32_t j=0;j<16;j++)for(uint32_t k=0;k<4;k++){
  uint32_t i=j+k*256;if(data[i]!=(0xcdefab00u|(i&255u)))fail(4);
 }
 for(uint32_t i=0;i<32;i++){
  if(f0(i)!=i*3u+5u||f1(i)!=(i^0xa5a55a5au)+7u||f2(i)!=(i>>3)+(i<<5)||f3(i)!=i*17u-11u)fail(5);
 }
 __asm__ volatile("fence rw,rw" ::: "memory"); __asm__ volatile("fence.i" ::: "memory"); if(f0(7)!=26u)fail(7);
 for(uint32_t i=16;i<256;i++)if(data[i]!=0x12340000u+i)fail(6);
 RESULT=0x600dcafeu;for(;;){}
}
