#include <stdint.h>
#include "epaper.h"
/* The camera pipeline owns K1/K2. Firmware mirrors its COMMITTED state. */
#define REG(offset) (*(volatile uint32_t *)(0xF8100000u + (offset)))
int main(void) {
    uint32_t last = 0xffffffffu, ui_divider = 0;
    epaper_start();
    for (;;) {
        uint32_t status = REG(0x00) & 0x1fffu;
        if (!ui_divider) {
            REG(0x20)=1;
            for (uint32_t i=0;i<20;i++) REG(0xa0+4*i)=REG(0x40+4*i);
            REG(0x24)=1;
        }
        ui_divider=(ui_divider+1u)&63u;
        if (status != last) {
            REG(0x04) = 0x10000u | status;
            last = status;
        }
        epaper_service();
    }
}
