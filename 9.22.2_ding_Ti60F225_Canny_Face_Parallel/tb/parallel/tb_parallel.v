`timescale 1ns/1ps
module tb_parallel;
 localparam W=64,H=48,HT=90,D=4*(HT+1)+14;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,de=0,vs=0,hs=1;reg[23:0] rgb=0;reg[2:0] mode=0;
 wire[23:0] out_rgb;wire od,ov,oh,overrun;
 parallel_video #(.WIDTH(W),.HEIGHT(H),.H_TOTAL(HT)) dut(clk,rst,rgb,de,vs,hs,mode,12'd40,12'd80,out_rgb,od,ov,oh,overrun);
 reg[26:0] refpipe[0:D]; integer k,x,y,f,t,count_edges,valid_edges,skin_pixels,clean_pixels;
 reg edge_map[0:W*H-1]; integer queue[0:W*H-1]; integer qhead,qtail,idx,dx,dy,nx,ny;
 integer rows[0:H-1];reg checking=0; reg [23:0] expected_rgb;
 always @(posedge clk) begin
 if(!rst) begin for(k=0;k<=D;k=k+1)refpipe[k]=0;end
 else begin
 for(k=D;k>0;k=k-1)refpipe[k]=refpipe[k-1];
 refpipe[0]={vs,hs,de,rgb};
 #1;
 if(checking) begin
 if({ov,oh,od}!==refpipe[D][26:24]) $fatal(1,"sync mismatch frame %d",f);
 if(mode==0 && od && out_rgb!==refpipe[D][23:0]) $fatal(1,"RGB alignment mismatch");
 if(dut.cv && dut.ade && (dut.ex!==dut.ax || dut.ey!==dut.ay)) $fatal(1,"Canny coord mismatch ex%0d ax%0d ey%0d ay%0d",dut.ex,dut.ax,dut.ey,dut.ay);
 if(dut.mv && dut.md && (dut.mx!==dut.mxa || dut.my!==dut.mya)) $fatal(1,"morph coordinate mismatch");
 if(dut.aligned_edge) begin count_edges=count_edges+1;rows[dut.ay]=rows[dut.ay]+1;edge_map[dut.ay*W+dut.ax]=1;end
 if(dut.cv) valid_edges=valid_edges+1;
 if(dut.sv && dut.skin) skin_pixels=skin_pixels+1;
 if(dut.md && dut.clean_skin) clean_pixels=clean_pixels+1;
 end
 end
 end
 task tick;begin @(negedge clk);end endtask
 initial begin
 count_edges=0;valid_edges=0;skin_pixels=0;clean_pixels=0;
 repeat(8)tick;rst=1;
 for(f=0;f<6;f=f+1)begin
 de=0;vs=0;rgb=0;repeat(HT*8)tick;vs=1;repeat(HT*2)tick;
 count_edges=0;valid_edges=0;skin_pixels=0;clean_pixels=0;for(y=0;y<H;y=y+1)rows[y]=0;for(idx=0;idx<W*H;idx=idx+1)edge_map[idx]=0;checking=1;
 for(y=0;y<H;y=y+1)begin
 for(x=0;x<HT;x=x+1)begin
 de=x<W;hs=x>=W+2;rgb=0;
 if(de)case(f)
 0:rgb=0;
 1:rgb=x>=32?24'hffffff:0;
 2:rgb=(x>=16 && x<48 && y>=12 && y<36)?24'hffffff:0;
 3:rgb=(x>=16 && x<48 && y>=12 && y<36)?24'hce9e7b:0;
 4:rgb=0;
 5:rgb=(x==32 && y==24)?24'hce9e7b:0;
 endcase
 tick;
 end
 end
 de=0;rgb=0;repeat(HT*8)tick;
 if(f==0 || f==4)if(count_edges!=0)$fatal(1,"black / stale frame edges %d",count_edges);
 if(f==1)begin
 if(count_edges!=H-8)$fatal(1,"vertical not single pixel got %d expected %d",count_edges,H-8);
 for(y=4;y<H-4;y=y+1)if(rows[y]!=1)$fatal(1,"vertical row %d has %d pixels",y,rows[y]);
 end
 if(f==2)begin
 if(count_edges!=108)$fatal(1,"rectangle pixel count %d",count_edges);
 qhead=0;qtail=0;
 for(idx=0;idx<W*H;idx=idx+1)if(edge_map[idx] && qtail==0)begin queue[0]=idx;qtail=1;edge_map[idx]=0;end
 while(qhead<qtail)begin
 idx=queue[qhead];qhead=qhead+1;
 for(dy=-1;dy<=1;dy=dy+1)for(dx=-1;dx<=1;dx=dx+1)begin
 nx=idx%W+dx;ny=idx/W+dy;
 if(nx>=0 && nx<W && ny>=0 && ny<H)if(edge_map[ny*W+nx])begin
 edge_map[ny*W+nx]=0;queue[qtail]=ny*W+nx;qtail=qtail+1;end
 end
 end
 if(qtail!=count_edges)$fatal(1,"rectangle contour is disconnected");
 end
 if(f==5 && (count_edges!=0 || skin_pixels!=1 || clean_pixels!=0))$fatal(1,"isolated skin noise not removed");
 if(f==3 && (skin_pixels!=768 || clean_pixels!=656))$fatal(1,"skin/morph not live");
 $display("PASS frame %d edge pixels %d valid %d skin %d clean %d",f,count_edges,valid_edges,skin_pixels,clean_pixels);
 end
 $display("PASS parallel end-to-end RGB/sync/coordinates, black, single-pixel step, rectangle, skin, stale clearing");$finish;
 end
 initial begin #2000000;$fatal(1,"timeout");end
endmodule
