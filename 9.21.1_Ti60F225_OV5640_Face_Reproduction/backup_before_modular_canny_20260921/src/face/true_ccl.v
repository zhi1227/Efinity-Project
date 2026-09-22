`timescale 1ns / 1ps
`define DL 3  // 把使能信号延迟若干周期，要求两行使能之间有足够间隔

// CCAL-based streaming CCL core.
// 重要修改：增加 SRST 同步复位分支，确保 x/y/状态/N 等在帧首被清零。

module true_ccl #(
  parameter Wb = 11,   // 2^Wb >= image width
  parameter Hb = 10,   // 2^Hb >= image height
  parameter Nb = 10    // label bits
)(
  input  clk,
  input  SRST,              // 1: run, 0: reset (a_rst_i(~SRST) to FIFOs/BRAM)
  input  DataEn,
  input  PixelData,         // 0: background, 1: foreground
  output OEn,
  output [89 - 3 * Wb - 2 * Hb - Nb - 1:0] Count,
  output [Wb - 1:0] XMin, 
  output [Wb - 1:0] XMax,
  output [Hb - 1:0] YMin,
  output [Hb - 1:0] YMax,
  output [Nb - 1:0] RealN
);
  reg  PrePixel, PreCombCur;
  reg  [2     :0] XStartEn;
  reg  [`DL   :0] DataEn_;
  reg  [Wb - 1:0] x, XStart, XEnd;
  reg  [Hb - 1:0] y;
  reg  [5     :0] PreState, NextPreState;
  reg  [2     :0] CurState, NextCurState;					 
  reg  [Nb - 1:0] N, InheritN;

  wire [89 - 3 * Wb - 2 * Hb - Nb - 1:0] oaCount; 
  wire [Wb - 1:0] oaXMin, oaXMax, oaBottomLineXMax;
  wire [Hb - 1:0] oaYMin, oaYMax;
  wire [Nb - 1:0] oaRealN;

  // FIFO empty flags
  wire CurEmpty, PreEmpty;

  // ------------------------------------------------------------------
  // 前向声明（wire 必须先声明再使用）。
  // 原代码把这几根 wire 写在下面使用之后，Verilog-2001 不允许，
  // Vivado 会报 VRFC 10-3380 "used before its declaration" / VRFC 10-2938。
  // Efinity 对此较宽松，所以问题一直没暴露。
  //   Start/End     ：像素的上升/下降沿（进入/离开前景）
  //   EnEnd         ：数据使能的上升沿（行结束）
  //   RealNEn       ：CC 表 B 口读数据里的 "real new" 标志位
  //   CurY/PreY     ：当前行号 / 上一段行号（PreY 只用到低 2 位）
  // ------------------------------------------------------------------
  wire Start, End, EnEnd;
  wire RealNEn, oaRealNEn;
  wire [Hb-1:0] CurY;
  wire [1:0]    PreY;
  wire [Wb-1:0] CurXStart, CurXEnd, PreXStart, PreXEnd, BottomLineXMax;
  wire [89 - 3*Wb - 2*Hb - Nb - 1:0] CurCount, bCount, iaCount;
  wire [Wb-1:0] bXMin, bXMax, bBottomLineXMax, iaXMin, iaXMax;
  wire [Hb-1:0] bYMin, bYMax, iaYMin, iaYMax;

  // 同步复位：将所有关键寄存器在 SRST=0 时复位
  always @(posedge clk) begin
    if (!SRST) begin
      PrePixel   <= 1'b0;
      XStartEn   <= 3'b000;
      DataEn_    <= {(`DL+1){1'b0}};
      x          <= {Wb{1'b0}};
      XStart     <= {Wb{1'b0}};
      XEnd       <= {Wb{1'b0}};
      y          <= {Hb{1'b0}};
      PreState   <= 6'b000001; // PreIDLE
      CurState   <= 3'b001;    // CurIDLE
      InheritN   <= {Nb{1'b0}};
    end else begin
      PrePixel <= DataEn ? PixelData : 1'b0;
      x        <= (DataEn || DataEn_[`DL])? x + 1     : 0;
      DataEn_  <= {DataEn_[`DL - 1:0], DataEn};
      
      if(Start)          XStart <= x;
      else if(EnEnd)     XStart <= 0;
      
      if(End)            XEnd   <= x;
      else if(EnEnd)     XEnd   <= 0;
      
      if(Start)          XStartEn[0] <= 1;
      else if(End)       XStartEn[0] <= 0;
      
      XStartEn[2:1] <= XStartEn[1:0];
      
      if(EnEnd)          y <= y + 1'b1; 
      
      if(PreCombCur)     InheritN <= RealN; 
      
      PreState <= NextPreState;
      CurState <= NextCurState;
    end
  end
  
  assign Start = PixelData && !PrePixel;  
  assign End   = !PixelData && PrePixel;
  assign EnEnd = !DataEn_[`DL - 1] && DataEn_[`DL];  
		 
  localparam PreIDLE = 6'b000001,
             PreDONE = 6'b000010,
             PreLOOK = 6'b000100,
             PreCCAL = 6'b001000,
             PreREAD = 6'b010000,
             PreWAIT = 6'b100000;  
  
  wire [2:0] yDiff = y[2:0] - {1'b0, PreY};
  reg NotC[1:0];
  always@(posedge clk) begin
    if (!SRST) begin
      NotC[0] <= 1'b0;
      NotC[1] <= 1'b0;
    end else begin
      NotC[0] <= XStart > PreXEnd + 1;
      NotC[1] <= NotC[0];
    end
  end
 
  wire LeftNotC  = PreXEnd + 1 < CurXStart;         
  wire RightNotC = CurXEnd + 1 < PreXStart;         
  wire Connect   = !LeftNotC && !RightNotC;         
  wire PreDoneC  = Connect && (CurXEnd >= PreXEnd); 
  wire CurDoneC  = Connect && (PreXEnd >= CurXEnd); 

  wire EmptyAndNotC = CurEmpty && (yDiff[1:0] > 2'b1 || ( 
                      yDiff[1:0] == 2'b1 && x > PreXEnd + 4 &&
                      ( (XStartEn[2] && NotC[1]) || !XStartEn[2] ) ));
  wire NotEmptyNotC = !CurEmpty && LeftNotC;
  wire NotEmptyDone = !CurEmpty && PreDoneC; 
                                                              
  wire [5:0]nextPre = RealNEn ? PreLOOK : (PreDoneC ? PreREAD : (CurState[2] ? PreWAIT : PreCCAL));
  
  always@(*)begin
    case(PreState)
      PreIDLE:
        if(!PreEmpty && (yDiff[1:0] != 2'b0)) begin  
          if((DataEn_[0] || DataEn_[`DL]) && EmptyAndNotC || NotEmptyNotC)            
            NextPreState = PreDONE;
          else if(!CurEmpty && Connect) begin
            NextPreState = nextPre;
            PreCombCur = RealNEn || CurState[2] ? 0 : 1;
          end else begin
            NextPreState = PreIDLE;
            PreCombCur = 0;
          end
        end
        else begin
          NextPreState = PreIDLE;
          PreCombCur = 0;
        end
			 
      PreLOOK: begin
        NextPreState = nextPre;         
        PreCombCur = RealNEn || CurState[2] ? 0 : 1;
      end
		
      PreCCAL:begin
        PreCombCur = !CurEmpty ? 1 : 0; 
        if(NotEmptyDone || NotEmptyNotC || EmptyAndNotC)
          NextPreState = PreREAD;
        else
          NextPreState = PreCCAL;
      end	

      PreWAIT: begin                  
        NextPreState = PreIDLE;		
        PreCombCur = 0;
      end
      default: begin
        NextPreState = PreIDLE;
        PreCombCur = 0;
      end
    endcase
  end
  
  localparam CurIDLE = 3'b001,  
             CurNEW  = 3'b010,    
             CurCCAL = 3'b100;   
				
  wire PreEmptyOrNotC = PreEmpty ||
                        (!PreEmpty && PreY == CurY[1:0]) ||
                        (!PreEmpty && RightNotC);

  wire CurCCALDone = PreEmptyOrNotC || (NextPreState[5:4] && CurDoneC) ;
  
  always@(*)begin
    case(CurState)	 
      CurIDLE:
        if(!CurEmpty) begin
          if(PreEmptyOrNotC)
            NextCurState = CurNEW;                     
          else if(!CurDoneC && NextPreState[4])
            NextCurState = CurCCAL;
          else
            NextCurState = CurIDLE;
        end
        else
          NextCurState = CurIDLE;
			 
      CurCCAL:                                         
        if(CurCCALDone)
          NextCurState = CurIDLE;
        else
          NextCurState = CurCCAL;	   
      default: NextCurState = CurIDLE;
    endcase
  end 
		 
  wire [Nb - 1:0] CurN, PreN; 

  wire PreWrCurRd = NextCurState[1] || (PreCombCur && CurDoneC) || (CurState[2] && CurCCALDone);  

  FIFO36x512 iCurrentLine(
    .clk_i(clk), 
    .a_rst_i(~SRST), 
    .wdata({4'b0, y, XStart, x - 1'b1}), 
    .wr_en_i(End),                       
    .rd_en_i(PreWrCurRd),                
    .rdata({CurY, CurXStart, CurXEnd}),
    .full_o(), 
    .empty_o(CurEmpty) 
  );    
  
  wire CCDone = ~RealNEn && (PreXEnd == BottomLineXMax) && (y != YMax);
  assign OEn = CCDone && NextPreState[1]; 
              
  wire PreRd = NextPreState[1] || NextPreState[4];      
  assign CurN =  NextCurState[1] ? N : (PreWrCurRd && PreCombCur ? RealN : InheritN);
  
  FIFO36x512 iPreviousLine(
    .clk_i(clk), 
    .a_rst_i(~SRST), 
    .wdata({0, CurY[1:0], CurN, CurXStart, CurXEnd}), 
    .wr_en_i(PreWrCurRd), 
    .rd_en_i(PreRd), 
    .rdata({PreY, PreN, PreXStart, PreXEnd}),
    .full_o(), 
    .empty_o(PreEmpty) 
  );

  wire CurCombPre = CurState[2] &&  NextPreState[5:4] && (InheritN != RealN);  
  wire CCwea = NextCurState[1] || CurCombPre;
               
  always@(posedge clk) begin
    if (!SRST) N <= {Nb{1'b0}};
    else if(NextCurState[1]) N <= N + 1'b1;
  end
  
  wire [89    :0] CCdina  = NextCurState[1] ? {CurCount, CurXStart, CurXEnd, CurY, CurY, CurXEnd, N, 1'b0} 
                                            : {iaCount, iaXMin, iaXMax, iaYMin, iaYMax, oaBottomLineXMax, oaRealN, oaRealNEn};
  wire [Nb - 1:0] CCaddra = NextCurState[1] ? N : InheritN; 
  wire [89    :0] CCdinb  = CurCombPre ? {79'b0,oaRealN,1'b1}
                                       : {bCount, bXMin, bXMax, bYMin, bYMax, bBottomLineXMax, RealN, RealNEn};
  
  assign CurCount = CurXEnd - CurXStart + 1'b1;
  assign bCount   = Count + CurCount;
  assign bXMin = CurXStart < XMin ? CurXStart : XMin;
  assign bXMax = CurXEnd > XMax ? CurXEnd : XMax;
  assign bBottomLineXMax = CurXEnd;
  assign bYMin = YMin;
  assign bYMax = CurY;
  wire CCweb = PreCombCur || CurCombPre;         
  wire [Nb - 1:0] CCaddrb = NextPreState[3:2] || CCweb ? RealN : PreN;            

  assign iaCount = oaCount + Count;
  assign iaXMin = XMin < oaXMin ? XMin : oaXMin;
  assign iaXMax = XMax > oaXMax ? XMax : oaXMax;
  assign iaYMin = YMin < oaYMin ? YMin : oaYMin;
  assign iaYMax = YMax > oaYMax ? YMax : oaYMax ;

  BlockRam90x1024 iCCList( 
    .clk(clk), 
    .we_a(CCwea),                            
    .addr_a(CCaddra), 
    .wdata_a(CCdina), 
    .rdata_a({oaCount, oaXMin, oaXMax, oaYMin, oaYMax, oaBottomLineXMax, oaRealN, oaRealNEn}), 
    .we_b(CCweb),                          
    .addr_b(CCaddrb), 
    .wdata_b(CCdinb), 
    .rdata_b({Count, XMin, XMax, YMin, YMax, BottomLineXMax, RealN, RealNEn})
  );
																									  
endmodule