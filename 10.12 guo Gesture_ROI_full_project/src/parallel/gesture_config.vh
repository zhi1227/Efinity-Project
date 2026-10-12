// Shared processing/display ROI: (40,40)..(1000,680) at 1280x720.
// Keep the complete upright hand inside it; reserve the right-side status UI.
`ifndef GESTURE_CONFIG_VH
`define GESTURE_CONFIG_VH
`define HAND_X0 (WIDTH/32)
`define HAND_X1 (WIDTH*25/32)
`define HAND_Y0 (HEIGHT/18)
`define HAND_Y1 (HEIGHT*17/18)
`endif
