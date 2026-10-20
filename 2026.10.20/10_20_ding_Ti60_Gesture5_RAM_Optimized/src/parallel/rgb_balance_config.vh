// Official-ISP comparison: FPGA spatial gains bypassed; old gains retained for rollback.
// ding, 2026-10-15. Compile-time camera RGB565 adjustment.
// Q8.8 gains: 256 = 1.0, 240 = 0.9375. These are experimental settings,
// not measured calibration coefficients. Rebuild after changing this file.
`ifndef RGB_BALANCE_CONFIG_VH
`define RGB_BALANCE_CONFIG_VH
`ifndef RGB_BALANCE_ENABLE
`define RGB_BALANCE_ENABLE 0
`endif
`ifndef RGB_BALANCE_CENTER_R
`define RGB_BALANCE_CENTER_R 256
`endif
`ifndef RGB_BALANCE_CENTER_G
`define RGB_BALANCE_CENTER_G 240
`endif
`ifndef RGB_BALANCE_CENTER_B
`define RGB_BALANCE_CENTER_B 256
`endif
`ifndef RGB_BALANCE_EDGE_R
`define RGB_BALANCE_EDGE_R 240
`endif
`ifndef RGB_BALANCE_EDGE_G
`define RGB_BALANCE_EDGE_G 256
`endif
`ifndef RGB_BALANCE_EDGE_B
`define RGB_BALANCE_EDGE_B 256
`endif
// Second optical trial: retain the previous curve at weights 0..64.
// Smooth knots at 128 (magenta halo), 192 (green ring), 256 (yellow core).
// These values are conservative trial gains, not a camera calibration.
`ifndef RGB_BALANCE_PROFILE_ENABLE
`define RGB_BALANCE_PROFILE_ENABLE 0
`endif
`ifndef RGB_BALANCE_OUTER_R
`define RGB_BALANCE_OUTER_R 240
`endif
`ifndef RGB_BALANCE_OUTER_G
`define RGB_BALANCE_OUTER_G 248
`endif
`ifndef RGB_BALANCE_OUTER_B
`define RGB_BALANCE_OUTER_B 248
`endif
`ifndef RGB_BALANCE_MID_R
`define RGB_BALANCE_MID_R 252
`endif
`ifndef RGB_BALANCE_MID_G
`define RGB_BALANCE_MID_G 232
`endif
`ifndef RGB_BALANCE_MID_B
`define RGB_BALANCE_MID_B 256
`endif
`ifndef RGB_BALANCE_CORE_R
`define RGB_BALANCE_CORE_R 248
`endif
`ifndef RGB_BALANCE_CORE_G
`define RGB_BALANCE_CORE_G 236
`endif
`ifndef RGB_BALANCE_CORE_B
`define RGB_BALANCE_CORE_B 256
`endif
`endif
