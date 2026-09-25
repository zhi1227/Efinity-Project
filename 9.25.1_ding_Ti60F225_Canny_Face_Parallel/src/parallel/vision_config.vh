// Active compile-time defaults. Change here and rebuild; stage 1 has no face UART writes.
// Board resolution, clocks, pinout, DDR and HDMI are deliberately not configured here.
`ifndef VISION_CONFIG_VH
`define VISION_CONFIG_VH
`define VISION_DEFAULT_MODE 3
`define VISION_CANNY_LOW 40
`define VISION_CANNY_HIGH 80
`define VISION_SKIN_CB_MIN 77
`define VISION_SKIN_CB_MAX 127
`define VISION_SKIN_CR_MIN 133
`define VISION_SKIN_CR_MAX 173
`define VISION_SKIN_Y_MIN 40
`define VISION_SKIN_Y_MAX 235
`define VISION_FACE_MAX_FACES 8
`define VISION_FACE_CELL_SHIFT 3
`define VISION_FACE_CELL_MIN 24
`define VISION_FACE_MIN_W 40
`define VISION_FACE_MIN_H 48
`define VISION_FACE_MAX_W 640
`define VISION_FACE_MAX_H 640
`define VISION_FACE_MIN_AREA 1800
`define VISION_FACE_MIN_FILL_PERCENT 25
`define VISION_FACE_MIN_RATIO_X10 6
`define VISION_FACE_MAX_RATIO_X10 16
// Mode 5: 0=Sobel binary, 1=Canny binary. Left half is unfiltered grayscale.
`define VISION_COMPARE_CANNY 0
// Modes 6/7 are unobstructed masks by default; set 1 for candidate boxes.
`define VISION_DEBUG_BOXES 0
`endif
