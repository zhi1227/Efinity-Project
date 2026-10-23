#include "epaper.h"
#ifdef EPD_HOST_TEST
extern uint32_t epd_read(uint32_t offset);
extern void epd_write(uint32_t offset, uint32_t value);
#else
static uint32_t epd_read(uint32_t offset) {
    return *(volatile uint32_t *)(0xF8100100u+offset);
}
static void epd_write(uint32_t offset, uint32_t value) {
    *(volatile uint32_t *)(0xF8100100u+offset)=value;
}
#endif
enum { COMMAND, DATA, DELAY_MS, SET_RST, WAIT_IDLE, FRAME, WAIT_REFRESH, FINISH };
#define OP(kind,value) ((uint16_t)(((kind)<<12)|(value)))
static const uint16_t program[] = {
    OP(SET_RST,1), OP(DELAY_MS,100), OP(SET_RST,0), OP(DELAY_MS,2),
    OP(SET_RST,1), OP(DELAY_MS,100), OP(WAIT_IDLE,0),
    OP(COMMAND,0x12), OP(WAIT_IDLE,0),
    OP(COMMAND,0x21), OP(DATA,0x40), OP(DATA,0),
    OP(COMMAND,0x3c), OP(DATA,5), OP(COMMAND,0x11), OP(DATA,3),
    OP(COMMAND,0x44), OP(DATA,0), OP(DATA,49),
    OP(COMMAND,0x45), OP(DATA,0), OP(DATA,0), OP(DATA,0x2b), OP(DATA,1),
    OP(COMMAND,0x4e), OP(DATA,0), OP(COMMAND,0x4f), OP(DATA,0), OP(DATA,0),
    OP(WAIT_IDLE,0), OP(COMMAND,0x24), OP(FRAME,0),
    OP(COMMAND,0x4e), OP(DATA,0), OP(COMMAND,0x4f), OP(DATA,0), OP(DATA,0),
    OP(COMMAND,0x26), OP(FRAME,0),
    OP(COMMAND,0x22), OP(DATA,0xf7), OP(COMMAND,0x20), OP(WAIT_REFRESH,0),
    OP(COMMAND,0x10), OP(DATA,1), OP(DELAY_MS,200), OP(FINISH,0)
};
static uint32_t since, tx_since;
static uint16_t pixel;
static uint8_t pc, waiting, seen_busy, stopped, tx_waiting;
static void fail(uint8_t code) { stopped=1; epd_write(0x10,0x80u|code); }
void epaper_start(void) {
    pc=0; pixel=0; waiting=0; seen_busy=0; stopped=0; tx_waiting=0;
    epd_write(0,4); epd_write(4,1); epd_write(0x10,1);
}
// One short step per call: menu polling continues during all transfers and waits.
void epaper_service(void) {
    uint32_t status, now, elapsed;
    uint16_t insn, value;
    uint8_t op, image_byte;
    if(stopped) return;
    status=epd_read(0); now=epd_read(0x0c);
    if(status&4) { fail(3); return; }
    if(status&1) {
        if(!tx_waiting) { tx_since=now; tx_waiting=1; }
        else if((uint32_t)(now-tx_since)>=1000) fail(4);
        return;
    }
    tx_waiting=0;
    insn=program[pc]; op=(uint8_t)(insn>>12); value=insn&0xfff;
    switch(op) {
    case COMMAND: case DATA:
        epd_write(8,value | (op==DATA ? 0x100u : 0)); ++pc; break;
    case SET_RST: epd_write(4,value); ++pc; break;
    case FRAME:
        if(pixel==0) { epd_write(0x10,2); epaper_image_reset(); }
        if(!epaper_image_next(&image_byte)) { fail(5); return; }
        epd_write(8,0x100u|image_byte);
        if(++pixel==EPAPER_IMAGE_BYTES) {
            if(!epaper_image_complete()) { fail(5); return; }
            pixel=0; ++pc;
        }
        break;
    case DELAY_MS: case WAIT_IDLE: case WAIT_REFRESH:
        if(!waiting) { waiting=1; since=now; seen_busy=0; }
        elapsed=(uint32_t)(now-since);
        if(status&2) seen_busy=1;
        if(op==DELAY_MS ? elapsed>=value :
            (elapsed>=10 && !(status&2) && (op==WAIT_IDLE || seen_busy))) {
            waiting=0; ++pc;
        } else if(op!=DELAY_MS) {
            if(elapsed>=30000) fail(1);
            else if(op==WAIT_REFRESH && !seen_busy && elapsed>=1000) fail(2);
        }
        break;
    case FINISH: epd_write(0x10,3); stopped=1; break;
    default: fail(3); break;
    }
}
