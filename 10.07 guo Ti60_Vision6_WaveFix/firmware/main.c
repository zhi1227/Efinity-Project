#include <stdint.h>
/* The camera pipeline owns K1/K2. Firmware mirrors its COMMITTED state. */
#define REG(offset) (*(volatile uint32_t *)(0xF8100000u + (offset)))
int main(void) {
    uint32_t last = 0xffffffffu;
    for (;;) {
        uint32_t status = REG(0x00) & 0x1fffu;
        if (status != last) {
            REG(0x04) = 0x10000u | status;
            last = status;
        }
    }
}
