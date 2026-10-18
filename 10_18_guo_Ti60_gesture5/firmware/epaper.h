#ifndef EPAPER_H
#define EPAPER_H
#include <stdint.h>
void epaper_start(void);
void epaper_service(void);
#define EPAPER_IMAGE_BYTES 15000u
extern const uint8_t epaper_image_packed[];
extern const uint16_t epaper_image_packed_size;
void epaper_image_reset(void);
int epaper_image_next(uint8_t *value);
int epaper_image_complete(void);
#endif
