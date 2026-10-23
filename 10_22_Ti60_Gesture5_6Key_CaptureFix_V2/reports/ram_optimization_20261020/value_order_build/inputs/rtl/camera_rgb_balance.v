// ding, 2026-10-15.
// 1280x720 OV5640 RGB565 byte stream: high byte, then low byte.
// Input VS is high throughout the active frame. DE gaps delimit lines.
// The first byte of each DE run is a high byte. An unmatched final high
// byte is discarded in the correction branch; the next DE run starts fresh.
// Input and output samples are separated by exactly six rising-edge periods.
// Frame sync is delayed with the data, allowing the final pixel to drain.
`include "rgb_balance_config.vh"

module camera_rgb_balance #(
 parameter ENABLE=`RGB_BALANCE_ENABLE,
 parameter CENTER_R=`RGB_BALANCE_CENTER_R,
 parameter CENTER_G=`RGB_BALANCE_CENTER_G,
 parameter CENTER_B=`RGB_BALANCE_CENTER_B,
 parameter EDGE_R=`RGB_BALANCE_EDGE_R,
 parameter EDGE_G=`RGB_BALANCE_EDGE_G,
 parameter EDGE_B=`RGB_BALANCE_EDGE_B,
 parameter PROFILE_ENABLE=`RGB_BALANCE_PROFILE_ENABLE,
 parameter OUTER_R=`RGB_BALANCE_OUTER_R,
 parameter OUTER_G=`RGB_BALANCE_OUTER_G,
 parameter OUTER_B=`RGB_BALANCE_OUTER_B,
 parameter MID_R=`RGB_BALANCE_MID_R,
 parameter MID_G=`RGB_BALANCE_MID_G,
 parameter MID_B=`RGB_BALANCE_MID_B,
 parameter CORE_R=`RGB_BALANCE_CORE_R,
 parameter CORE_G=`RGB_BALANCE_CORE_G,
 parameter CORE_B=`RGB_BALANCE_CORE_B
)(
 input wire clk,rst_n,vs_i,de_i,
 input wire [7:0] data_i,
 output reg vs_o,de_o,
 output reg [7:0] data_o
);
 localparam IDENTITY = !ENABLE || (CENTER_R==256 && CENTER_G==256 && CENTER_B==256 &&
                                  EDGE_R==256 && EDGE_G==256 && EDGE_B==256 &&
                                  (!PROFILE_ENABLE || (OUTER_R==256 && OUTER_G==256 && OUTER_B==256 &&
                                   MID_R==256 && MID_G==256 && MID_B==256 &&
                                   CORE_R==256 && CORE_G==256 && CORE_B==256)));
 reg [5:0] vs_delay;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin vs_delay<=0;vs_o<=0;end
  else begin vs_delay<={vs_delay[4:0],vs_i};vs_o<=vs_delay[5];end
 end

 generate if(IDENTITY) begin: bypass
  // Includes data during blanking and malformed/odd DE runs: strictly byte
  // equivalent to the input with the same six-period latency as correction.
  reg [5:0] de_delay;
  reg [7:0] byte_delay [0:5];
  integer n;
  always @(posedge clk or negedge rst_n) begin
   if(!rst_n) begin
    de_delay<=0;de_o<=0;data_o<=0;
    for(n=0;n<6;n=n+1) byte_delay[n]<=0;
   end else begin
    de_delay<={de_delay[4:0],de_i};de_o<=de_delay[5];
    byte_delay[0]<=data_i;
    for(n=1;n<6;n=n+1) byte_delay[n]<=byte_delay[n-1];
    data_o<=byte_delay[5];
   end
  end
 end else begin: correct
  reg phase,de_q;
  reg [7:0] first_byte;
  reg [10:0] x,pair_x;
  reg [9:0] y,pair_y;
  reg pair_valid,weights_valid,centre_valid,gain_valid,corrected_valid;
  reg [15:0] pair_rgb,weights_rgb,centre_rgb,gain_rgb,corrected_rgb;
  reg [8:0] wx,wy,centre_weight;
  reg [15:0] gain_r,gain_g,gain_b;
  reg low_pending;
  reg [7:0] saved_low;
  wire [17:0] centre_product=wx*wy;

  // Constant multiply/shift approximations to a 0..256 triangular ramp.
  // Both central columns/rows reach 256; all four image edges reach zero.
  // No run-time division and no line/frame RAM is needed.
  function [8:0] weight_x;
   input [10:0] px;
   reg [10:0] distance_x;
   reg [20:0] scaled;
   begin
    distance_x=px<640?px:11'd1279-px;
    scaled=distance_x*8'd205+21'd256;
    weight_x=(scaled>>9)>256?9'd256:(scaled>>9);
   end
  endfunction
  // Central-only retune. The old edge curve remains exact through weight 64.
  // Three equal 64-step segments need only constant shifts, with signed
  // half-away-from-zero rounding. Interpolation is continuous at all knots.
  function [15:0] profile_gain;
   input integer centre,edge_gain,outer_gain,mid_gain,core_gain;
   input [8:0] weight;
   reg signed [31:0] left_gain,right_gain,position,adjustment;
   begin
    if(!PROFILE_ENABLE || weight<=64)
     profile_gain=blend_gain(centre,edge_gain,weight);
    else begin
     if(weight<=128) begin
      left_gain=blend_gain(centre,edge_gain,9'd64);right_gain=outer_gain;position=weight-64;
     end else if(weight<=192) begin
      left_gain=outer_gain;right_gain=mid_gain;position=weight-128;
     end else begin
      left_gain=mid_gain;right_gain=core_gain;position=weight-192;
     end
     adjustment=(right_gain-left_gain)*position;
     if(adjustment>=0) adjustment=(adjustment+32)>>>6;
     else adjustment=-(((-adjustment)+32)>>>6);
     profile_gain=left_gain+adjustment;
    end
   end
  endfunction
  function [8:0] weight_y;
   input [9:0] py;
   reg [9:0] distance_y;
   reg [20:0] scaled;
   begin
    distance_y=py<360?py:10'd719-py;
    scaled=distance_y*9'd365+21'd256;
    weight_y=(scaled>>9)>256?9'd256:(scaled>>9);
   end
  endfunction
  function [15:0] blend_gain;
   input integer centre,edge_gain;
   input [8:0] weight;
   reg signed [31:0] adjustment;
   begin
    adjustment=(centre-edge_gain)*$signed({1'b0,weight});
    if(adjustment>=0) adjustment=(adjustment+128)>>>8;
    else adjustment=-(((-adjustment)+128)>>>8);
    blend_gain=edge_gain+adjustment;
   end
  endfunction
  function [4:0] scale5;
   input [4:0] channel;
   input [15:0] gain;
   reg [31:0] product;
   begin
    product=(channel*gain+32'd128)>>8;
    scale5=product>31?5'd31:product[4:0];
   end
  endfunction
  function [5:0] scale6;
   input [5:0] channel;
   input [15:0] gain;
   reg [31:0] product;
   begin
    product=(channel*gain+32'd128)>>8;
    scale6=product>63?6'd63:product[5:0];
   end
  endfunction

  always @(posedge clk or negedge rst_n) begin
   if(!rst_n) begin
    phase<=0;de_q<=0;first_byte<=0;x<=0;y<=0;pair_x<=0;pair_y<=0;
    pair_valid<=0;weights_valid<=0;centre_valid<=0;gain_valid<=0;corrected_valid<=0;
    pair_rgb<=0;weights_rgb<=0;centre_rgb<=0;gain_rgb<=0;corrected_rgb<=0;
    wx<=0;wy<=0;centre_weight<=0;gain_r<=0;gain_g<=0;gain_b<=0;
    low_pending<=0;saved_low<=0;de_o<=0;data_o<=0;
   end else begin
    de_q<=de_i;pair_valid<=0;
    // Only the input assembler resets at frame/line boundaries. Never clear
    // the arithmetic or serializer here: they still contain trailing pixels.
    if(!vs_i) begin phase<=0;x<=0;y<=0;end
    else if(!de_i) begin
     phase<=0;x<=0;
     if(de_q && y<719) y<=y+1'b1;
    end else if(!phase) begin first_byte<=data_i;phase<=1;end
    else begin
     pair_rgb<={first_byte,data_i};pair_x<=x;pair_y<=y;pair_valid<=1;phase<=0;
     if(x<1279) x<=x+1'b1;
    end

    weights_valid<=pair_valid;weights_rgb<=pair_rgb;
    wx<=weight_x(pair_x);wy<=weight_y(pair_y);
    centre_valid<=weights_valid;centre_rgb<=weights_rgb;
    centre_weight<=(centre_product+18'd128)>>8;
    gain_valid<=centre_valid;gain_rgb<=centre_rgb;
    gain_r<=profile_gain(CENTER_R,EDGE_R,OUTER_R,MID_R,CORE_R,centre_weight);
    gain_g<=profile_gain(CENTER_G,EDGE_G,OUTER_G,MID_G,CORE_G,centre_weight);
    gain_b<=profile_gain(CENTER_B,EDGE_B,OUTER_B,MID_B,CORE_B,centre_weight);
    corrected_valid<=gain_valid;
    corrected_rgb<={scale5(gain_rgb[15:11],gain_r),scale6(gain_rgb[10:5],gain_g),scale5(gain_rgb[4:0],gain_b)};

    de_o<=0;data_o<=0;
    if(corrected_valid) begin
     de_o<=1;data_o<=corrected_rgb[15:8];saved_low<=corrected_rgb[7:0];low_pending<=1;
    end else if(low_pending) begin de_o<=1;data_o<=saved_low;low_pending<=0;end
   end
  end
 end endgenerate

 // synthesis translate_off
 initial begin
  if(CENTER_R<0 || CENTER_R>1024 || CENTER_G<0 || CENTER_G>1024 || CENTER_B<0 || CENTER_B>1024 ||
     EDGE_R<0 || EDGE_R>1024 || EDGE_G<0 || EDGE_G>1024 || EDGE_B<0 || EDGE_B>1024)
   $fatal(1,"camera_rgb_balance: gains must be in 0..1024 (Q8.8)");
  if((PROFILE_ENABLE!=0 && PROFILE_ENABLE!=1) ||
     OUTER_R<0 || OUTER_R>1024 || OUTER_G<0 || OUTER_G>1024 || OUTER_B<0 || OUTER_B>1024 ||
     MID_R<0 || MID_R>1024 || MID_G<0 || MID_G>1024 || MID_B<0 || MID_B>1024 ||
     CORE_R<0 || CORE_R>1024 || CORE_G<0 || CORE_G>1024 || CORE_B<0 || CORE_B>1024)
   $fatal(1,"camera_rgb_balance: invalid central profile parameters");
 end
 // synthesis translate_on
endmodule
