// RTL translation of rameloni/canny-edge-detecion-hls for the verified
// Ti60F225 OV5640 -> DDR3 -> HDMI 1280x720 pixel stream.

module hls_gaussian5x5 #(
    parameter WIDTH = 1280
)(
    input clk, input rst_n,
    input [7:0] gray_in,
    input de_in, input vs_in, input hs_in,
    output reg [7:0] gray_out,
    output reg de_out, output reg vs_out, output reg hs_out
);
    reg [7:0] h0, h1, h2, h3;
    reg [11:0] hsum;
    reg [11:0] hsum_d;
    reg de_h, de_r;
    reg vs_h, vs_r;
    reg hs_h, hs_r;

    wire [11:0] horizontal_sum = {4'b0,h0}
        + ({4'b0,h1} << 2)
        + ({4'b0,h2} << 2) + ({4'b0,h2} << 1)
        + ({4'b0,h3} << 2)
        + {4'b0,gray_in};

    wire [11:0] line1, line2, line3, line4;
    active_delay_ram #(.DATA_WIDTH(12), .DELAY(WIDTH)) u_gd1
        (.clk(clk),.rst_n(rst_n),.en(de_h),.din(hsum),.dout(line1));
    active_delay_ram #(.DATA_WIDTH(12), .DELAY(2*WIDTH)) u_gd2
        (.clk(clk),.rst_n(rst_n),.en(de_h),.din(hsum),.dout(line2));
    active_delay_ram #(.DATA_WIDTH(12), .DELAY(3*WIDTH)) u_gd3
        (.clk(clk),.rst_n(rst_n),.en(de_h),.din(hsum),.dout(line3));
    active_delay_ram #(.DATA_WIDTH(12), .DELAY(4*WIDTH)) u_gd4
        (.clk(clk),.rst_n(rst_n),.en(de_h),.din(hsum),.dout(line4));

    wire [15:0] vertical_sum = {4'b0,line4}
        + ({4'b0,line3} << 2)
        + ({4'b0,line2} << 2) + ({4'b0,line2} << 1)
        + ({4'b0,line1} << 2)
        + {4'b0,hsum_d};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h0<=0; h1<=0; h2<=0; h3<=0; hsum<=0; hsum_d<=0;
            de_h<=0; de_r<=0; de_out<=0;
            vs_h<=0; vs_r<=0; vs_out<=0;
            hs_h<=0; hs_r<=0; hs_out<=0;
            gray_out<=0;
        end else begin
            de_h <= de_in; de_r <= de_h; de_out <= de_r;
            vs_h <= vs_in; vs_r <= vs_h; vs_out <= vs_r;
            hs_h <= hs_in; hs_r <= hs_h; hs_out <= hs_r;
            hsum_d <= hsum;
            if (de_in) begin
                hsum <= horizontal_sum;
                h0 <= h1; h1 <= h2; h2 <= h3; h3 <= gray_in;
            end else begin
                h0<=0; h1<=0; h2<=0; h3<=0;
            end
            if (de_r)
                gray_out <= vertical_sum[15:8];
            else
                gray_out <= 0;
        end
    end
endmodule

module hls_sobel3x3 #(
    parameter WIDTH = 1280
)(
    input clk, input rst_n,
    input [7:0] gray_in,
    input de_in, input vs_in, input hs_in,
    output reg [9:0] grad_out,
    output reg de_out, output reg vs_out, output reg hs_out
);
    wire [7:0] row1, row2;
    active_delay_ram #(.DATA_WIDTH(8),.DELAY(WIDTH)) u_sd1
        (.clk(clk),.rst_n(rst_n),.en(de_in),.din(gray_in),.dout(row1));
    active_delay_ram #(.DATA_WIDTH(8),.DELAY(2*WIDTH)) u_sd2
        (.clk(clk),.rst_n(rst_n),.en(de_in),.din(gray_in),.dout(row2));

    reg [7:0] gray_d;
    reg de_d, vs_d, hs_d;
    reg [7:0] tl,tc,ml,mc,bl,bc;
    wire [10:0] gx_pos = {3'b0,row2}+{2'b0,row1,1'b0}+{3'b0,gray_d};
    wire [10:0] gx_neg = {3'b0,tl}+{2'b0,ml,1'b0}+{3'b0,bl};
    wire [10:0] gy_pos = {3'b0,tl}+{2'b0,tc,1'b0}+{3'b0,row2};
    wire [10:0] gy_neg = {3'b0,bl}+{2'b0,bc,1'b0}+{3'b0,gray_d};
    wire signed [11:0] gx = $signed({1'b0,gx_pos})-$signed({1'b0,gx_neg});
    wire signed [11:0] gy = $signed({1'b0,gy_pos})-$signed({1'b0,gy_neg});
    wire [11:0] ax = gx[11] ? -gx : gx;
    wire [11:0] ay = gy[11] ? -gy : gy;
    wire [12:0] mag_full = {1'b0,ax}+{1'b0,ay};
    wire [7:0] mag_sat = (mag_full > 13'd255) ? 8'hff : mag_full[7:0];

    // Extend before shifting. In Verilog the result of a shift keeps the
    // width of its left operand, so shifting ax directly loses upper bits.
    wire [19:0] ax_ext = {8'b0,ax};
    wire [19:0] ay256 = {ay,8'b0};
    wire [19:0] ax106 = (ax_ext<<6)+(ax_ext<<5)+(ax_ext<<3)+(ax_ext<<1);
    wire [19:0] ax618 = (ax_ext<<9)+(ax_ext<<6)+(ax_ext<<5)+(ax_ext<<3)+(ax_ext<<1);
    reg [1:0] direction;
    always @* begin
        if (ay256 <= ax106)
            direction = 2'd0;
        else if (ay256 >= ax618)
            direction = 2'd2;
        else if (gx[11] == gy[11])
            direction = 2'd1;
        else
            direction = 2'd3;
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            gray_d<=0; de_d<=0; vs_d<=0; hs_d<=0;
            tl<=0;tc<=0;ml<=0;mc<=0;bl<=0;bc<=0;
            grad_out<=0;de_out<=0;vs_out<=0;hs_out<=0;
        end else begin
            gray_d<=gray_in; de_d<=de_in; vs_d<=vs_in; hs_d<=hs_in;
            de_out<=de_d; vs_out<=vs_d; hs_out<=hs_d;
            if(de_d) begin
                grad_out <= {direction,mag_sat};
                tl<=tc; tc<=row2; ml<=mc; mc<=row1; bl<=bc; bc<=gray_d;
            end else begin
                grad_out<=0; tl<=0;tc<=0;ml<=0;mc<=0;bl<=0;bc<=0;
            end
        end
    end
endmodule

module hls_nonmax3x3 #(
    parameter WIDTH = 1280
)(
    input clk, input rst_n,
    input [9:0] grad_in,
    input de_in, input vs_in, input hs_in,
    output reg [7:0] mag_out,
    output reg de_out, output reg vs_out, output reg hs_out
);
    wire [9:0] row1,row2;
    active_delay_ram #(.DATA_WIDTH(10),.DELAY(WIDTH)) u_nd1
        (.clk(clk),.rst_n(rst_n),.en(de_in),.din(grad_in),.dout(row1));
    active_delay_ram #(.DATA_WIDTH(10),.DELAY(2*WIDTH)) u_nd2
        (.clk(clk),.rst_n(rst_n),.en(de_in),.din(grad_in),.dout(row2));
    reg [9:0] grad_d;
    reg de_d,vs_d,hs_d;
    reg [9:0] tl,tc,ml,mc,bl,bc;
    reg [7:0] ref1,ref2;
    always @* begin
        case(mc[9:8])
            2'd0: begin ref1=ml[7:0];   ref2=row1[7:0];  end
            2'd1: begin ref1=row2[7:0]; ref2=bl[7:0];    end
            2'd2: begin ref1=tc[7:0];   ref2=bc[7:0];    end
            default: begin ref1=tl[7:0]; ref2=grad_d[7:0]; end
        endcase
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            grad_d<=0;de_d<=0;vs_d<=0;hs_d<=0;
            tl<=0;tc<=0;ml<=0;mc<=0;bl<=0;bc<=0;
            mag_out<=0;de_out<=0;vs_out<=0;hs_out<=0;
        end else begin
            grad_d<=grad_in;de_d<=de_in;vs_d<=vs_in;hs_d<=hs_in;
            de_out<=de_d;vs_out<=vs_d;hs_out<=hs_d;
            if(de_d) begin
                mag_out <= ((mc[7:0]>=ref1)&&(mc[7:0]>=ref2)) ? mc[7:0] : 8'd0;
                tl<=tc;tc<=row2;ml<=mc;mc<=row1;bl<=bc;bc<=grad_d;
            end else begin
                mag_out<=0;tl<=0;tc<=0;ml<=0;mc<=0;bl<=0;bc<=0;
            end
        end
    end
endmodule

module hls_double_threshold #(
    parameter LOW_THRESHOLD=40,
    parameter HIGH_THRESHOLD=80
)(
    input clk,input rst_n,input [7:0] mag_in,
    input de_in,input vs_in,input hs_in,
    output reg [1:0] state_out,
    output reg de_out,output reg vs_out,output reg hs_out
);
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin state_out<=0;de_out<=0;vs_out<=0;hs_out<=0; end
        else begin
            de_out<=de_in;vs_out<=vs_in;hs_out<=hs_in;
            if(!de_in) state_out<=0;
            else if(mag_in>=HIGH_THRESHOLD) state_out<=2'd2;
            else if(mag_in>LOW_THRESHOLD) state_out<=2'd1;
            else state_out<=2'd0;
        end
    end
endmodule

module hls_hysteresis3x3 #(
    parameter WIDTH=1280
)(
    input clk,input rst_n,input [1:0] state_in,
    input de_in,input vs_in,input hs_in,
    output reg edge_out,
    output reg de_out,output reg vs_out,output reg hs_out
);
    wire [1:0] row1,row2;
    active_delay_ram #(.DATA_WIDTH(2),.DELAY(WIDTH)) u_hd1
        (.clk(clk),.rst_n(rst_n),.en(de_in),.din(state_in),.dout(row1));
    active_delay_ram #(.DATA_WIDTH(2),.DELAY(2*WIDTH)) u_hd2
        (.clk(clk),.rst_n(rst_n),.en(de_in),.din(state_in),.dout(row2));
    reg [1:0] state_d;
    reg de_d,vs_d,hs_d;
    reg [1:0] tl,tc,ml,mc,bl,bc;
    wire neighbor_strong = (tl==2)||(tc==2)||(row2==2)||(ml==2)
                         ||(row1==2)||(bl==2)||(bc==2)||(state_d==2);
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state_d<=0;de_d<=0;vs_d<=0;hs_d<=0;
            tl<=0;tc<=0;ml<=0;mc<=0;bl<=0;bc<=0;
            edge_out<=0;de_out<=0;vs_out<=0;hs_out<=0;
        end else begin
            state_d<=state_in;de_d<=de_in;vs_d<=vs_in;hs_d<=hs_in;
            de_out<=de_d;vs_out<=vs_d;hs_out<=hs_d;
            if(de_d) begin
                edge_out <= (mc==2) || ((mc==1) && neighbor_strong);
                tl<=tc;tc<=row2;ml<=mc;mc<=row1;bl<=bc;bc<=state_d;
            end else begin
                edge_out<=0;tl<=0;tc<=0;ml<=0;mc<=0;bl<=0;bc<=0;
            end
        end
    end
endmodule

module hls_canny_stream_720p #(
    parameter WIDTH=1280,
    parameter HEIGHT=720,
    parameter LOW_THRESHOLD=40,
    parameter HIGH_THRESHOLD=80
)(
    input clk,input rst_n,input [23:0] rgb_in,
    input de_in,input vs_in,input hs_in,
    output reg [23:0] rgb_out,
    output reg de_out,output reg vs_out,output reg hs_out
);
    wire [9:0] gray_sum={2'b0,rgb_in[23:16]>>2}+{2'b0,rgb_in[15:8]>>1}+{2'b0,rgb_in[7:0]>>2};
    wire [7:0] gray=gray_sum[7:0];
    wire [7:0] gpix; wire gde,gvs,ghs;
    wire [9:0] grad; wire sde,svs,shs;
    wire [7:0] nmag; wire nde,nvs,nhs;
    wire [1:0] state; wire tde,tvs,ths;
    wire edge_bit; wire ede,evs,ehs;

    hls_gaussian5x5 #(.WIDTH(WIDTH)) u_gauss
      (.clk(clk),.rst_n(rst_n),.gray_in(gray),.de_in(de_in),.vs_in(vs_in),.hs_in(hs_in),.gray_out(gpix),.de_out(gde),.vs_out(gvs),.hs_out(ghs));
    hls_sobel3x3 #(.WIDTH(WIDTH)) u_sobel
      (.clk(clk),.rst_n(rst_n),.gray_in(gpix),.de_in(gde),.vs_in(gvs),.hs_in(ghs),.grad_out(grad),.de_out(sde),.vs_out(svs),.hs_out(shs));
    hls_nonmax3x3 #(.WIDTH(WIDTH)) u_nms
      (.clk(clk),.rst_n(rst_n),.grad_in(grad),.de_in(sde),.vs_in(svs),.hs_in(shs),.mag_out(nmag),.de_out(nde),.vs_out(nvs),.hs_out(nhs));
    hls_double_threshold #(.LOW_THRESHOLD(LOW_THRESHOLD),.HIGH_THRESHOLD(HIGH_THRESHOLD)) u_thresh
      (.clk(clk),.rst_n(rst_n),.mag_in(nmag),.de_in(nde),.vs_in(nvs),.hs_in(nhs),.state_out(state),.de_out(tde),.vs_out(tvs),.hs_out(ths));
    hls_hysteresis3x3 #(.WIDTH(WIDTH)) u_hyst
      (.clk(clk),.rst_n(rst_n),.state_in(state),.de_in(tde),.vs_in(tvs),.hs_in(ths),.edge_out(edge_bit),.de_out(ede),.vs_out(evs),.hs_out(ehs));

    reg [10:0] out_x; reg [9:0] out_y;
    wire border_valid=(out_x>=8)&&(out_x<WIDTH-8)&&(out_y>=8)&&(out_y<HEIGHT-8);
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin out_x<=0;out_y<=0;rgb_out<=0;de_out<=0;vs_out<=0;hs_out<=0; end
        else begin
            de_out<=ede;vs_out<=evs;hs_out<=ehs;
            rgb_out<=(ede&&border_valid)?{24{edge_bit}}:24'h0;
            if(!evs) begin out_x<=0;out_y<=0; end
            else if(ede) begin
                if(out_x==WIDTH-1) begin out_x<=0;out_y<=(out_y==HEIGHT-1)?0:out_y+1'b1; end
                else out_x<=out_x+1'b1;
            end else out_x<=0;
        end
    end
endmodule
