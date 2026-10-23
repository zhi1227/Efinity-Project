from pathlib import Path
import shutil
P=Path(__file__).resolve().parents[1];R=P/'reports/cpu_font_ram';run=P/'sim_cache_stress';run.mkdir(exist_ok=True)
shutil.copyfile(P/'firmware/start.S',run/'start.S');shutil.copyfile(P/'firmware/linker.ld',run/'linker.ld')
(run/'cache_stress.c').write_text('''#include <stdint.h>
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
''')
(run/'tb_cache_stress.sv').write_text('''`timescale 1ns/1ps
module tb_cache_stress;
 reg clk=0,reset=1;always #5 clk=~clk;
 wire[15:0]addr;wire sel,en,wr;wire[31:0]wd;
 EfxSapphireSoc dut(.io_systemClk(clk),.io_asyncReset(reset),
 .jtagCtrl_tck(1'b0),.jtagCtrl_tdi(1'b0),.jtagCtrl_enable(1'b0),.jtagCtrl_capture(1'b0),.jtagCtrl_shift(1'b0),.jtagCtrl_update(1'b0),.jtagCtrl_reset(1'b0),
 .system_uart_0_io_rxd(1'b1),.io_apbSlave_0_PADDR(addr),.io_apbSlave_0_PSEL(sel),.io_apbSlave_0_PENABLE(en),.io_apbSlave_0_PWRITE(wr),.io_apbSlave_0_PWDATA(wd),
 .io_apbSlave_0_PRDATA(32'd0),.io_apbSlave_0_PREADY(1'b1),.io_apbSlave_0_PSLVERROR(1'b0),
 .system_spi_0_io_data_0_read(1'b1),.system_spi_0_io_data_1_read(1'b1),.system_spi_0_io_data_2_read(1'b1),.system_spi_0_io_data_3_read(1'b1));
 integer cycles=0;
 initial begin repeat(10)@(negedge clk);reset=0;end
 always @(posedge clk)begin cycles<=cycles+1;if(cycles>2000000)$fatal(1,"Cache stress timeout");
 if(sel&&en&&wr&&addr==16'h0008)begin
 if(wd!==32'h600dcafe)$fatal(1,"Cache alias/byte/halfword/instruction/fence failure %h",wd);
 $display("PASS: real CPU cache stress: 1KiB index aliases, full address tags, byte/halfword masks, instruction conflict misses, fence; cycles=%0d",cycles);$finish;end end
endmodule
''')
print('Prepared isolated real-CPU cache stress firmware; production firmware untouched')
