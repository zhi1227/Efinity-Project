from pathlib import Path
import hashlib
import json
import re
from datetime import datetime
import xml.etree.ElementTree as ET

root=Path(__file__).resolve().parents[1]
receipt=json.loads((root/'reports/build_receipt.json').read_text(encoding='utf-8-sig'))
report=(root/'outflow/Ti60_Demo.timing.rpt').read_text()
section=report.split('Setup (Max) Clock Relationship',1)[1].split('Clock Relationship Summary (end)',1)[0]
setup,hold=section.split('Hold (Min) Clock Relationship')
row_re=r'^\s+(\S+)\s+(\S+)\s+(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+\([RF]-[RF]\)'
sets={k:[(a,b,float(c),float(d)) for a,b,c,d in re.findall(row_re,s,re.M)] for k,s in [('setup',setup),('hold',hold)]}
assert all(r[3]>=0 for rows in sets.values() for r in rows)
ns={'e':'http://www.efinixinc.com/enf_proj'}
project=ET.parse(root/'Ti60_Demo.xml')
sources=[n.attrib['name'] for n in project.findall('./e:design_info/e:design_file',ns)]
assert all((root/p).is_file() for p in sources)
assert not any('reference/' in p or '/sdram/' in p for p in sources)
tests={}
for name in ['math','controls','gesture','video','720p','hud']:
    log=(root/f'reports/tb_ep1_{name}.sim.log').read_text()
    match=re.search(r'^PASS .*$',log,re.M)
    assert match and not re.search(r'\bFAIL\b|Fatal:|ERROR:',log),name
    tests[name]=match.group(0)
original=root.parent/'FPGA-Edge-Detection-Project1/rtl'
for copy in (root/'reference/original_rtl').rglob('*'):
    if copy.is_file():
        source=original/copy.relative_to(root/'reference/original_rtl')
        assert source.read_bytes()==copy.read_bytes(),source
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest().upper()
paths=[root/'example_top.v',root/'Ti60_Demo.xml',root/'Ti60_Demo.peri.xml',root/'Ti60_Demo.pt.sdc']
paths += [root/p for p in sources if p!='example_top.v']
paths += list((root/'src/project1').glob('*'))
paths += [p for p in (root/'ip').rglob('*') if p.is_file() and p.suffix.lower() in {'.v','.sv','.vh','.vhd','.json','.mem','.hex','.bin'}]
paths += [root/'outflow/Ti60_Demo.bit']
manifest={p.relative_to(root).as_posix():digest(p) for p in sorted(set(paths))}
(root/'reports/delivery_hashes.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
summary={'recorded_at':datetime.now().isoformat(), 'device':receipt['device'],
         'boot_mode':'M3 SOBEL','boot_threshold':100,'reset_button':'K3 / RESET (J5 CRESET_N)',
         'bit_sha256':digest(root/'outflow/Ti60_Demo.bit'),'jtag_sram_success':receipt['board_programmed'],
         'setup_relationships':len(sets['setup']),'hold_relationships':len(sets['hold']),
         'minimum_setup_slack_ns':min(r[3] for r in sets['setup']),
         'minimum_hold_slack_ns':min(r[3] for r in sets['hold']),
         'tests':tests,'original_rtl_unchanged':True,
         'physical_hdmi_acceptance':'pending_user_observation',
         'real_hand_classification':'not_measured','field_threshold_calibration':'not_performed'}
(root/'reports/validation_summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
route=(root/'outflow/Ti60_Demo.route.rpt').read_text()
resources=[s.strip() for s in route.splitlines() if re.match(r'^(XLRs|Memory Blocks|DSP Blocks):',s)]
text=f'''# 交付与验证状态

记录时间：{summary['recorded_at']}。

## 已完成

- 独立 Ti60F225/C4 工程；原项目 RTL 与参考副本逐文件核对一致。
- 本次修订：下载后默认 M3 SOBEL 黑底白边，T:100，无需按键进入；用户确认 K3/RESET 是硬件复位，模式操作仍使用 K1。
- Efinity 2025.1 完整综合、布局布线、位流生成通过。
- {len(sets['setup'])} 组 setup、{len(sets['hold'])} 组 hold 全部非负；最小裕量分别为 **{summary['minimum_setup_slack_ns']:.3f} ns / {summary['minimum_hold_slack_ns']:.3f} ns**。
- JTAG SRAM 下载：**{'成功' if receipt['board_programmed'] else '未执行'}**，Ti60 ID `0x10660A79`，6 MHz；没有写 Flash。
- 下载日志：`{receipt.get('jtag_log','')}`；构建日志：`{receipt['log']}`。

## 仿真证据

'''+''.join(f'- {message}\n' for message in tests.values())+f'''
数字转换和屏幕字符已通过 RTL 测试，仿真输出预览见 `hud_preview.png`，它不是实机 HDMI 照片。

## 资源与文件

'''+''.join(f'- {line}\n' for line in resources)+f'''
- 位流：`outflow/Ti60_Demo.bit`（{(root/'outflow/Ti60_Demo.bit').stat().st_size:,} 字节）。
- SHA256：`{summary['bit_sha256']}`。
- 工程源文件、IP 和 bit 的哈希：`reports/delivery_hashes.json`。
- 定量结果：`reports/validation_summary.json`。
- 源清单保留所有实际实例化的板级模块，包括 `Sensor_Image_XYCrop.v`；未使用原 Cyclone IV SDRAM、PLL、ALTSQRT 和引脚约束。

## 实机边界

下载工具已确认成功，但尚未收到本次修订后的实际 HDMI 画面和按键反馈。默认 M3 出图、八模式操作、真人三类手势的效果仍待现场观察，不能标记为已经通过。

三类规则严格沿用原项目的 F 门限；F 是外接框面积/极值更新次数，受目标尺寸和背景影响。本轮已补齐数据通路与计算错误，未获得实测数据，因此未做现场门限校准，也未测得真人识别准确率。见 `reports/BOARD_ACCEPTANCE.md`。

## 告警核对

已核对输出引脚报告和本地核心板 V1.4 原理图第 7 页网络表：K1=N2/CSI、K2=M2/CSO，均为 1.8 V LVCMOS；K3=J5/CRESET_N，为专用硬件复位，不参与模式选择。按 K3 可能重新从 Flash 配置，需重下载本 SRAM 版本。板级工程保留未启用 CSI/DSI/LCD 接口的约束及相关工具告警；这些并非本次新增图像链路。新链路完全运行在已约束的 `clk_pixel` 域，异步按键采用两级同步与消抖。

综合中仍有底层 IP 未使用端口、常量、总线截位，以及 DSP 打包后的未用时钟使能告警；原始日志保留用于追溯。本次没有通过新增 false path 掩盖像素处理时序。
'''
(root/'reports/DELIVERY.md').write_text(text,encoding='utf-8')
board=root/'reports/BOARD_ACCEPTANCE.md'
s=board.read_text(encoding='utf-8').replace('规划阶段已读到 0x10660A79；下载时再次核对','下载前再次读取 0x10660A79，单 Ti60')
if receipt['board_programmed']:
    s=s.replace('| 本移植 bit 下载 | 待下载日志 |','| 本移植 bit 下载 | 成功，6 MHz JTAG SRAM |')
board.write_text(s,encoding='utf-8')
print(json.dumps(summary,indent=2))
