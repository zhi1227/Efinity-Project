from pathlib import Path
import json,hashlib,shutil
P=Path(__file__).resolve().parents[1]
B=Path((P/'reports/vision8/io29_migration_backup_path.txt').read_text(encoding='utf-8-sig').strip())
old=json.loads((B/'reports/build_verified.json').read_text(encoding='utf-8-sig'))
new=json.loads((P/'reports/build_verified.json').read_text(encoding='utf-8-sig'))
for bench in ['tb_vision8_controls','tb_io29_freeze_ddr','tb_vision8_ddr']:
    log=(P/f'reports/vision8/{bench}.log').read_text(errors='replace')
    assert 'PASS:' in log and 'Fatal:' not in log and 'Error:' not in log,bench
assert new['bit_sha256']!=old['bit_sha256']
for ext in ['bit','hex']:
    src=P/f'outflow/Ti60_Demo.{ext}'
    assert hashlib.sha256(src.read_bytes()).hexdigest()==new[f'{ext}_sha256']
    shutil.copy2(src,P/f'outflow/Ti60_Demo_IO29_20261011.{ext}')
rows='\n'.join(f'| {k} | {old["resources"][k]["used"]} | {v["used"]} | {v["used"]-old["resources"][k]["used"]:+d} |' for k,v in new['resources'].items())
report=f'''# IO29 按钮迁移说明（2026-10-11）

冻结、抓拍、阈值减少等原 IO35 按钮功能全部迁移至 IO29。IO28 的引脚配置与接收逻辑未改。仅修改八模式集成工程，原工程和 RAM 优化基线未改；迁移前版本备份在 `{B}`。

## 接线与下载

- 新按钮信号：J7 / User_3V3_IO29 / DC3-40 第34脚 / FPGA D1（GPIOL_P_16）。将原 IO35 按钮信号移到这里，按钮供电与地线保持原接法。
- 按下为低电平、松开为高电平。输入配置与 IO28 一致：1.8 V LVCMOS、普通输入、无内部上下拉、无接口寄存器。
- IO35 不再承担按钮输入。IO28、板载 K1/K2 功能保持原样。
- 下载文件：[Ti60_Demo_IO29_20261011.bit](10_11_liu_Ti60_Vision8_Buttons_Integrated/outflow/Ti60_Demo_IO29_20261011.bit)。这是新生成的迁移版，请使用这个文件。

## IO29 操作

短按动作在松开后触发；长按约 2 秒，长按松开不会再次触发短按。

| 场景 | 短按 IO29 | 长按 IO29 |
| --- | --- | --- |
| 原图、Canny、红边、赛博、人脸模式 | 冻结 / 恢复 | 无额外操作 |
| 四帧对比 | 抓取一帧，依次填入四格 | 清空四格 |
| 阈值调节 | 减少当前选定阈值 | 冻结 / 恢复 |
| 手势模式 | 正常识别时冻结 / 恢复 | 无额外操作 |

手势录入过程沿用板载 K1 操作；IO29 在录入过程中不触发冻结。

## 编译资源对比

比较对象是迁移前 IO35 修正版与本次 IO29 版。

| 资源 | IO35 版 | IO29 版 | 差值 |
| --- | ---: | ---: | ---: |
{rows}

最小 setup slack：{old['min_setup_slack_ns']} → {new['min_setup_slack_ns']} ns；最小 hold slack：{old['min_hold_slack_ns']} → {new['min_hold_slack_ns']} ns。

## 验证结果

- IO29 唯一映射到 D1/GPIOL_P_16，方向、输入电压与配置核对通过；IO28 与备份逐项相同。
- 按键控制仿真通过，覆盖低电平短按、长按、去抖、上电按住、模式切换及阈值操作。
- IO29 到真实 FIFO/DDR 控制链路的冻结仿真通过：冻结后显示帧保持，恢复后切换到新帧，再按可以重新冻结。
- 常规 DDR 回归、八模式菜单像素仿真、字体分银行一致性验证通过；菜单按钮提示已改为 IO29。
- Efinity map/interface/pnr/pgm 全部通过，资源、时序、编译输入一致性检查通过。
- 原工程、RAM 优化基线、Canny 算法保持不变。其它算法/CPU/电子纸测试沿用此前结果，本次不声称重新完成这些测试。
- 尚未下载硬件，实际按键与屏幕表现需要上板确认。下载后先在原图模式短按并松开 IO29，画面应冻结；再次短按恢复。

bit SHA256：`{new['bit_sha256']}`
'''
(P.parent/'IO29按钮迁移说明_20261011.md').write_text(report,encoding='utf-8')
(P/'IO29按钮迁移说明_20261011.md').write_text(report.replace('10_11_liu_Ti60_Vision8_Buttons_Integrated/outflow/','outflow/'),encoding='utf-8')
print('Wrote IO29 report and verified bit/hex aliases')
