# Write the handoff only after complete tests and selected build exist.
from pathlib import Path
import json,re
P=Path(__file__).resolve().parents[1];R=P/'reports/inline_threshold'
def read(f):return json.loads(f.read_text(encoding='utf-8-sig'))
t=read(R/'tests.json');b=read(R/'selected_build.json');assert t['status']=='PASS' and len(t['checks'])==32 and b['status']=='PASS'
o=Path(read(R/'protection.json')['source']);old=read(o/'reports/build_verified.json');new=b['build']
rows=[]
for title,key in [('XLR','XLRs'),('RAM块','Memory Blocks'),('DSP','DSP Blocks'),('全局时钟GBUF','Global Clocks (GBUF)')]:
 x=old['resources'][key]['used'];y=new['resources'][key]['used'];rows.append(f'| {title} | {x} | {y} | {y-x:+d} |')
resource='\n'.join(rows)
body=f'''本轮最终32项源代码/日志SHA绑定检查全部通过，证据见`reports/inline_threshold/tests.json`及`final_logs/`。每项检查都要求完整最终PASS与仿真结束标记，不把中途某个模式的PASS当成整组通过。此前中断的CPU/电子纸日志单独归档，最终验收采用重新完整运行的结果。

| 验证层级 | 实际结果 |
| --- | --- |
| 参考与RTL逐像素 | 新旧原版双实例接收同输入，7×720p共6,451,200有效像素零差异，valid/VS/HS周期一致；默认参数算法输出与原版一致，界面文字属于有意变化 |
| 动态阈值RTL | 12帧、147,456像素；Canny/红边/赛博/左右对照真实响应，极值及有效视频中编辑不跳变 |
| 四键控制RTL | 95项检查、7次参数提交；另运行原IO28消抖/临界长按/上下文完整台架 |
| 抓拍集成RTL | 实际controls+parallel+frames，4算法、16锁帧；每张2304组32位数据逐对一致，46,080次HDMI标签采样正确；后续pending修改不影响保存T和元数据 |
| UI与字库RTL | 5,301,248菜单像素、646,144字库像素；267个仍共用的旧字形逐像素保留 |
| 原功能RTL回归 | 23项全部通过，含五手势录入/识别、DDR/FIFO、摄像头通路、PiP、四帧和人脸候选；旧控制/七场景台架分别由新版95项和更强原版golden替代 |
| 真实RISC-V CPU | 完整8模式、每模式614400像素，共4,915,200像素；真实APB/CDC/帧提交/LVDS通过 |
| 真实RISC-V电子纸 | 完整30033 SPI字节、两图层、reset/BUSY和刷新期间菜单状态更新通过；台架缩短等待参数，不是硬件刷新耗时测量 |
| 综合/接口/布局布线/位流 | 当前505个生产输入与新构建绑定，map/interface/pnr/pgm全部PASS |
| 实体板卡 | 未执行；未下载SRAM、未写Flash，实际相机FPS和端到端延迟均未测量 |

原版资源是本任务开始前已经完成且已核对哈希的历史构建，本轮没有重新编译原版；新版本为本轮新鲜完整构建。

| 资源 | 原版历史构建 | 本轮新构建 | 增量 |
| --- | ---: | ---: | ---: |
{resource}

全局最小setup/hold分别为 **+{new['min_setup_slack_ns']:.3f}/+{new['min_hold_slack_ns']:.3f} ns**。原像素约束13.441ns（约74.4MHz）未改；clk_pixel setup/hold为+2.949/+0.026ns。新IO34唯一异步终点已核对为`controls/c/meta~FF.D`，其后同步路径未豁免；Efinity同步器报告无警告，本轮未另外执行形式CDC或MTBF测量。

已选择当前新构建到本目录`outflow/Ti60_Demo.bit`和`.hex`，没有覆盖继承的旧outflow；旧产物已在复制后移到`reports/inline_threshold/original_outflow`，只作历史。选择记录`selected_build.json`绑定来源、生产输入和所有输出SHA。

- bit SHA-256：`{new['bit_sha256']}`
- hex SHA-256：`{new['hex_sha256']}`

原IO28/29/35管脚逐行核对不变，唯一新管脚A9/GPIOT_N_11为IO34、1.8V输入。综合警告按各自最后一次综合段比较为399→388；不是零警告工程。新增菜单两处窄化分别在有界绘制坐标内（ty0..15、ci0..2），K1/K2未使用移除是本轮有意屏蔽；未发现新增隐式网、功能悬空、锁存器或多驱动警告。四项interface物理邻距提示仍保留，其中LVDS邻距因新增IO34而扩展，需上板观察GPIO/LVDS耦合；没有删约束或降频来获得通过。详见`build_detail_audit.json`。

本轮实际完整编译使用的英文stage为`D:\\Github_Project\\fpga_build\\inline_threshold_20261020_final`，执行`inline_threshold_build.py prepare`、`build`、`collect`三个阶段；既有stage不可原样重建，复现须改用新路径。

仿真预览：[八模式菜单](reports/fourkey/ui/eight_modes_rtl.png)、[默认边缘画面](reports/inline_threshold/video/default_modes_rtl.png)。这些是RTL输出渲染，均不是实物屏幕照片。
'''
start='<!-- INLINE_FINAL_RESULTS -->';end='<!-- /INLINE_FINAL_RESULTS -->'
f=P/'README_4Key_InlineThreshold.md';text=f.read_text(encoding='utf-8');assert start in text
if end in text:text=re.sub(re.escape(start)+r'.*?'+re.escape(end),lambda m:start+'\n\n'+body+'\n'+end,text,flags=re.S)
else:
 left,right=text.split(start,1);heading=right.find('\n## ')
 assert heading>=0;text=left+start+'\n\n'+body+'\n'+end+'\n'+right[heading:]
f.write_text(text,encoding='utf-8')
f=P/'README.md';text=f.read_text(encoding='utf-8')
short=f'\n{start}\n\n本轮32项验收全部PASS；7帧720p共6,451,200算法有效像素与原版一致，另有95项四键控制、23项原功能回归及真实CPU/电子纸完整仿真。新完整构建：XLR {new["resources"]["XLRs"]["used"]}、RAM184、DSP39，setup/hold +{new["min_setup_slack_ns"]:.3f}/+{new["min_hold_slack_ns"]:.3f}ns。当前bit/hex已选入outflow，未上板下载。详见完整说明的结果表和已知物理接口告警。\n\n{end}\n'
if start in text:text=re.sub(re.escape(start)+r'.*?'+re.escape(end),lambda m:short.strip(),text,flags=re.S)
else:text+=short
f.write_text(text,encoding='utf-8')
print('PASS: Chinese handoff filled from 32 completed checks and selected build evidence')
