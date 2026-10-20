#include "epaper.h"

/* One byte per service call; no heap, scanline buffer or full-frame buffer. */
static uint16_t source, decoded;
static uint8_t remaining, repeated, repeated_value;

void epaper_image_reset(void) {
    source = 0;
    decoded = 0;
    remaining = 0;
    repeated = 0;
    repeated_value = 0;
}

int epaper_image_next(uint8_t *value) {
    uint8_t control;
    if (decoded >= EPAPER_IMAGE_BYTES) return 0;
    if (remaining == 0) {
        if (source >= epaper_image_packed_size) return 0;
        control = epaper_image_packed[source++];
        remaining = (uint8_t)((control & 0x7fu) + 1u);
        repeated = control & 0x80u;
        if (remaining > EPAPER_IMAGE_BYTES - decoded) return 0;
        if (repeated) {
            if (source >= epaper_image_packed_size) return 0;
            repeated_value = epaper_image_packed[source++];
        } else if (remaining > epaper_image_packed_size - source) {
            return 0;
        }
    }
    *value = repeated ? repeated_value : epaper_image_packed[source++];
    --remaining;
    ++decoded;
    return 1;
}

int epaper_image_complete(void) {
    return decoded == EPAPER_IMAGE_BYTES && remaining == 0 &&
           source == epaper_image_packed_size;
}
