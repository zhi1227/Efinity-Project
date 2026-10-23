from pathlib import Path
import json,re,xml.etree.ElementTree as ET,hashlib
P=Path(__file__).resolve().parents[3]
R=Path(__file__).resolve().parent
source=(P/'src/vision/line_buffer_3x3.v').read_text(encoding='utf-8-sig')
original=source.replace('module line_buffer_3x3 #(', 'module line_buffer_3x3_current #(')
(R/'line_buffer_current.v').write_text(original,encoding='utf-8')
marker='\tend else begin : separate_wide_lines'
replacement='''	end else if (DWIDTH <= 10 && (WIDTH <= 512 ||
	             (DWIDTH >= 6 && WIDTH > 1024 && WIDTH <= 1536))) begin : banked_wide_lines
		// 512 x 20 is the useful BRAM geometry for two packed 8-bit lines.
		// Read-bank selection is registered alongside the one-clock RAM read.
		localparam BANKS=(WIDTH+511)/512;
		localparam BANK_AW=(AWIDTH>9)?AWIDTH-9:1;
		wire [2*DWIDTH-1:0] bank_q[0:BANKS-1];
		reg [BANK_AW-1:0] read_bank;
		genvar bi;
		for(bi=0;bi<BANKS;bi=bi+1)begin : storage
			localparam DEPTH=(WIDTH-bi*512<512)?WIDTH-bi*512:512;
			(* ram_style = "block" *) (* ramstyle = "block" *)
			reg [2*DWIDTH-1:0] lines[0:DEPTH-1];
			reg [2*DWIDTH-1:0] q;
			always @(posedge clk)begin
				if(de_d1 && (x_d1>>9)==bi)lines[x_d1[8:0]]<={rd1_dout,cur_d1};
				q<=lines[x_i[8:0]];
			end
			assign bank_q[bi]=q;
		end
		always @(posedge clk)read_bank<=x_i>>9;
		// An illegal column selects an out-of-range bank or tail address,
		// preserving the original array's unknown simulation read value.
		always @*{rd2_dout,rd1_dout}=bank_q[read_bank];
	end else begin : separate_wide_lines'''
assert source.count(marker)==1
candidate=source.replace(marker,replacement)
candidate=candidate.replace('// Keep wide-pixel packing unchanged: its BRAM geometry is already efficient.', '// Wider byte streams use 512-word banks; 12/14-bit paths keep their layout.')
(R/'line_buffer_3x3.v').write_text(candidate,encoding='utf-8')
top='''module wide_line_top(input clk,rst_n,frame_start,de_i,input[10:0]x_i,input[9:0]y_i,input[7:0]data_i,
 output[71:0]window_o,output window_valid,output[10:0]x_o,output[9:0]y_o);
 MODULE #(.WIDTH(1280),.DWIDTH(8),.AWIDTH(11)) dut(clk,rst_n,frame_start,de_i,x_i,y_i,data_i,window_o,window_valid,x_o,y_o);
endmodule
'''
ns='http://www.efinixinc.com/enf_proj';ET.register_namespace('efx',ns);q=lambda t:'{'+ns+'}'+t
for name,mod,src in [('current','line_buffer_3x3_current','line_buffer_current.v'),('candidate','line_buffer_3x3','line_buffer_3x3.v')]:
 d=R/name;d.mkdir(exist_ok=True)
 (d/'top.v').write_text(top.replace('MODULE',mod),encoding='utf-8')
 (d/'line.v').write_text((R/src).read_text(encoding='utf-8'),encoding='utf-8')
 tree=ET.parse(P/'Ti60_Demo.xml');root=tree.getroot();root.set('name','wide_line')
 info=root.find(q('design_info'));info.clear();info.set('def_veri_version','verilog_2k');info.set('def_vhdl_version','vhdl_2008');info.set('unified_flow','false')
 ET.SubElement(info,q('top_module'),name='wide_line_top')
 for file in ['top.v','line.v']:ET.SubElement(info,q('design_file'),name=file,version='default',library='default')
 root.find(q('constraint_info')).clear();root.find(q('ip_info')).clear()
 syn=root.find(q('synthesis'))
 for child in list(syn):
  if child.get('name')=='include':syn.remove(child)
 tree.write(d/'wide_line.xml',encoding='utf-8',xml_declaration=True)
bench=(P/'sim_ramopt/tb_ramopt_buffers.sv').read_text(encoding='utf-8')
line=bench[bench.index('module ramopt_line_case'):bench.index('module ramopt_window7_case')]
line=line.replace('CROP=0)', 'CROP=0,ILLEGAL=0)').replace('line_buffer_3x3_baseline','line_buffer_3x3_current')
line=line.replace('x=de?col-12+CROP:0;y=row;', '''x=de?col-12+CROP:0;y=row;
  if(ILLEGAL&&col>=12+W&&col<20+W)begin de=1;x=col-12;end''')
topbench='''module tb_wide;
 reg clk=0,rst_n=0;integer cycle=0;always #5 clk=~clk;
 always @(posedge clk)cycle<=cycle+1;
 initial begin
  repeat(4)@(negedge clk);rst_n=1;
  wait(cycle==19003);#2;rst_n=0;#17;rst_n=1;
  wait(cycle==45017);#2;rst_n=0;#23;rst_n=1;
  wait(cycle==90000);@(negedge clk);
  $display("PASS: wide banked line cycle-exact equivalence, 18 configurations, 90000 clocks; widths1/2/3/4/5/8/9/10/12/14, 1280/640/319 columns, sparse DE/crop/illegal columns/reset");$finish;
 end
'''
cases=[(1280,1,0,0),(1280,2,0,0),(1280,8,0,0),(1280,12,0,0),(1280,14,0,0),(319,1,0,0),(640,2,0,0),(1280,1,3,0),(1280,14,3,0),
 (1280,3,0,0),(1280,4,0,0),(1280,5,0,0),(1280,9,0,0),(1280,10,0,0),(1280,8,3,0),(319,8,0,0),(1280,8,0,1),(319,8,0,1)]
for i,(w,d,c,iv) in enumerate(cases):topbench+=f' ramopt_line_case #(.W({w}),.DW({d}),.CROP({c}),.ILLEGAL({iv})) l{i}(clk,rst_n,cycle);\n'
topbench+=' initial begin #1000000;$fatal(1,"wide line timeout");end\nendmodule\n'
s=R/'s';s.mkdir(exist_ok=True);(s/'tb_wide.sv').write_text('`timescale 1ns/1ps\n'+line+topbench,encoding='utf-8')
(R/'input_hashes.json').write_text(json.dumps({'production_line_sha256':hashlib.sha256((P/'src/vision/line_buffer_3x3.v').read_bytes()).hexdigest(),'candidate_sha256':hashlib.sha256(candidate.encode()).hexdigest()},indent=2),encoding='utf-8')
print('Prepared isolated line candidate; production RTL unchanged')
