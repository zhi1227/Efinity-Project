// Five upper horizontal probes plus six vertical probes for a sideways palm.
// No frame buffer. Small state arrays may map to LUT/FF or RAM in synthesis.
// The reference box belongs to the previous completed frame; the controller
// verifies its association with the current CCL result before using the probes.
module gesture_features(input clk,rst_n,enable,frame_start,de,bit_i,
 input[10:0]x,input[9:0]y,input box_valid,input[41:0]box,
 output reg valid,output reg[41:0]reference_box,
 output reg[2:0]one_votes,two_votes,many_votes,
 output reg[2:0]thumb_votes,solid_votes,cross_votes,join_votes);
 wire[10:0]x0=box[10:0],x1=box[21:11],bw=x1-x0+1;
 wire[9:0]y0=box[31:22],bh=box[41:32]-y0+1;
 wire probe=y==y0+(bh>>3)||y==y0+((bh*3)>>4)||y==y0+(bh>>2)||
            y==y0+((bh*5)>>4)||y==y0+((bh*3)>>3);
 wire[10:0]min_run=(bw>>5)<3?11'd3:(bw>>5);
 reg[10:0]run_length,occupied;
 reg[2:0]runs,ones,twos,many,rows;
 reg[41:0]sample_box;
 wire ended=run_length>=min_run;
 wire[3:0]row_runs={1'b0,runs}+ended;
 // Shape measurements at additional cross-sections. Separate a side thumb
 // above a broad closed fist from a centred extended index finger.
 wire lower_probe=y==y0+(bh>>1)||y==y0+((bh*5)>>3)||y==y0+((bh*3)>>2)||y==y0+((bh*7)>>3);
 wire tip_probe=y<=y0+(bh>>2);
 wire join_probe=y==y0+((bh*5)>>4)||y==y0+((bh*3)>>3);
 wire measure=probe||lower_probe;
 reg[10:0]m_length,m_pixels,m_first,m_last;
 reg[3:0]m_runs;reg m_seen,m_centre;
 reg[2:0]thumb_acc,solid_acc,gap_acc,tip_acc;
 wire[4:0]m_total={1'b0,m_runs}+(m_length>=min_run);
 wire[11:0]m_span={1'b0,m_last}-{1'b0,m_first}+1;
 wire[12:0]m_mid={2'd0,m_first}+{2'd0,m_last}-{2'd0,x0}-{2'd0,x0};
 always @(posedge clk)begin
  if(!rst_n||!enable)begin
   thumb_votes<=0;solid_votes<=0;cross_votes<=0;join_votes<=0;
   thumb_acc<=0;solid_acc<=0;gap_acc<=0;tip_acc<=0;
   m_length<=0;m_pixels<=0;m_first<=0;m_last<=0;m_runs<=0;m_seen<=0;m_centre<=0;
  end else if(frame_start)begin
   thumb_votes<=thumb_acc;solid_votes<=solid_acc;cross_votes<=gap_acc;join_votes<=tip_acc;
   thumb_acc<=0;solid_acc<=0;gap_acc<=0;tip_acc<=0;
   m_length<=0;m_pixels<=0;m_runs<=0;m_seen<=0;m_centre<=0;
  end else if(de&&box_valid&&measure)begin
   if(x==x0)begin
    m_length<=bit_i?1:0;m_pixels<=bit_i?1:0;m_first<=x;m_last<=x;m_runs<=0;m_seen<=bit_i;m_centre<=0;
   end else if(x>x0&&x<=x1)begin
    if(bit_i)begin
     m_length<=m_length+1'b1;m_pixels<=m_pixels+1'b1;m_seen<=1;m_last<=x;
     if(!m_seen)m_first<=x;
     if(x>=x0+((bw*7)>>4)&&x<=x0+((bw*9)>>4))m_centre<=1;
    end else begin if(m_length>=min_run&&m_runs<15)m_runs<=m_runs+1'b1;m_length<=0;end
   end else if(x==x1+1)begin
    if(probe&&m_total==1&&m_pixels*8>=bw&&m_pixels*2<=bw&&
       (m_mid*10<bw*9||m_mid*10>bw*11))thumb_acc<=thumb_acc+1'b1;
    if(lower_probe&&m_total==1&&m_pixels*5>=bw*3)solid_acc<=solid_acc+1'b1;
    if(tip_probe&&m_total==2&&m_pixels*5>=bw&&m_pixels*4<=bw*3)gap_acc<=gap_acc+1'b1;
    if(join_probe&&m_total==1&&m_pixels*5>=bw*2)tip_acc<=tip_acc+1'b1;
    m_length<=0;m_pixels<=0;m_runs<=0;m_seen<=0;m_centre<=0;
   end
  end
 end
 reg[9:0]v_length[0:5];reg[2:0]v_runs[0:5];reg[2:0]vertical_many;
 wire[9:0]min_vertical=(bh>>5)<3?10'd3:(bh>>5);
 wire[10:0]column_x[0:5];
 assign column_x[0]=x0+(bw>>3);assign column_x[1]=x0+(bw>>2);
 assign column_x[2]=x0+((bw*3)>>3);assign column_x[3]=x0+((bw*5)>>3);
 assign column_x[4]=x0+((bw*3)>>2);assign column_x[5]=x0+((bw*7)>>3);
 integer k;
 always @(posedge clk)begin
  if(!rst_n||!enable||frame_start)begin
   vertical_many<=0;for(k=0;k<6;k=k+1)begin v_length[k]<=0;v_runs[k]<=0;end
  end else if(de&&box_valid)begin
   for(k=0;k<6;k=k+1)if(x==column_x[k])begin
    if(y==y0)begin v_length[k]<=bit_i?1:0;v_runs[k]<=0;end
    else if(y>y0&&y<=box[41:32])begin
     if(bit_i)v_length[k]<=v_length[k]+1'b1;
     else begin if(v_length[k]>=min_vertical&&v_runs[k]<7)v_runs[k]<=v_runs[k]+1'b1;v_length[k]<=0;end
    end else if(y==box[41:32]+1)begin
     if(({1'b0,v_runs[k]}+(v_length[k]>=min_vertical))>=3&&
        ({1'b0,v_runs[k]}+(v_length[k]>=min_vertical))<=6)vertical_many<=vertical_many+1'b1;
    end
   end
  end
 end
 always @(posedge clk)begin
  if(!rst_n||!enable)begin
   valid<=0;reference_box<=0;one_votes<=0;two_votes<=0;many_votes<=0;
   run_length<=0;occupied<=0;runs<=0;ones<=0;twos<=0;many<=0;rows<=0;sample_box<=0;
  end else if(frame_start)begin
   valid<=rows==5;reference_box<=sample_box;
   one_votes<=ones;two_votes<=twos;many_votes<=many>vertical_many?many:vertical_many;
   run_length<=0;occupied<=0;runs<=0;ones<=0;twos<=0;many<=0;rows<=0;
  end else if(de&&box_valid&&probe)begin
   if(x==x0)begin
    sample_box<=box;run_length<=bit_i?1:0;occupied<=bit_i?1:0;runs<=0;
   end else if(x>x0&&x<=x1)begin
    if(bit_i)begin run_length<=run_length+1'b1;occupied<=occupied+1'b1;end
    else begin if(ended&&runs<7)runs<=runs+1'b1;run_length<=0;end
   end else if(x==x1+1)begin
    if(rows<7)rows<=rows+1'b1;
    if(occupied>=min_run)begin
     if(row_runs==1&&occupied*3<bw*2)ones<=ones+1'b1;
     if(row_runs==2&&occupied*8<bw*7)twos<=twos+1'b1;
     if(row_runs>=3&&row_runs<=6)many<=many+1'b1;
    end
    run_length<=0;occupied<=0;runs<=0;
   end
  end
 end
endmodule

// Raw class 1 is open-palm motion evidence, not a separate displayed gesture.
module gesture_shape(input valid,input[9:0]fill,input[19:0]ratio,
 input[2:0]one_votes,two_votes,many_votes,thumb_votes,solid_votes,cross_votes,join_votes,
 output reg[2:0]gesture);
 always @*begin
  gesture=0;
  if(valid)begin
   if(many_votes>=2&&fill>=200&&fill<=850&&ratio>=450&&ratio<=2300)gesture=1;
   else if(cross_votes>=1&&join_votes>=1&&two_votes>=1&&two_votes<=3&&solid_votes>=3&&many_votes==0&&fill>=450&&fill<=900&&ratio>=900&&ratio<=2100)gesture=3;
   else if(thumb_votes>=3&&solid_votes>=2&&many_votes==0&&two_votes==0&&fill>=400&&fill<=860&&ratio>=1000&&ratio<=2300)gesture=2;
  end
 end
endmodule
