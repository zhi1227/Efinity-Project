from pathlib import Path
P=Path(__file__).resolve().parents[1]
B=Path((P/'reports/vision8/io29_migration_backup_path.txt').read_text(encoding='utf-8-sig').strip())
assert B.is_dir() and B.is_relative_to(P/'backups')
paths=[P/'example_top.v',P/'Ti60_Demo.peri.xml',P/'Ti60_Demo.pt.sdc',P/'README.md']
paths+=list((P/'rtl').glob('*.v'))+list((P/'sim').glob('*.sv'))
paths += [P/'tools/test_all.ps1',P/'tools/test_vision8.ps1',P/'tools/generate_font.py',P/'tools/write_vision8_report.py']
for p in paths:
 text=p.read_text(encoding='utf-8-sig')
 if 'io35' not in text and 'IO35' not in text:continue
 text=text.replace('io35','io29').replace('IO35','IO29')
 if p.name=='Ti60_Demo.peri.xml':
  assert 'name="io29_button_i" gpio_def="GPIOT_P_11"' in text
  text=text.replace('name="io29_button_i" gpio_def="GPIOT_P_11"','name="io29_button_i" gpio_def="GPIOL_P_16"')
 if p.name in ('README.md','write_vision8_report.py'):
  text=text.replace('J9 / User_3V3_IO29 | 40 | B9 / GPIOT_P_11','J7 / User_3V3_IO29 | 34 | D1 / GPIOL_P_16')
  text=text.replace('IO29（第40脚/B9）','IO29（第34脚/D1）')
  text=text.replace('IO34、IO29 不占作按钮','IO34、IO35 不占作按钮')
  text=text.replace('IO34、IO29 不占作按钮功能','IO34、IO35 不占作按钮功能')
 if p.name=='write_vision8_report.py':
  old='本轮 IO29 修正：按用户实测改为“按下低、松开高”；IO28 保留原接收逻辑及引脚配置，顶层接线未改。'
  text=text.replace(old,'本轮冻结/抓拍/阈值减少功能从IO35迁移到IO29（J7/DC3-40第34脚/D1），保留按下低、松开高；IO28接收逻辑和引脚配置未改，顶层只重命名该按钮输入。')
  text=text.replace('IO29冻结键修正说明_20261011.md','IO29按钮迁移说明_20261011.md')
 p.write_text(text,encoding='utf-8')
for old,new in [('sim/tb_io35_freeze_ddr.sv','sim/tb_io29_freeze_ddr.sv')]:
 (P/old).rename(P/new)
for file in ['tools/verify_io35_configuration.py','tools/write_io35_fix_report.py','IO35冻结键修正说明_20261011.md']:
 p=P/file
 if p.exists():p.rename(B/('历史_'+p.name))
print('Migrated active RTL/top/SDC/GPIO/tests/UI/docs from IO35 to IO29; historical backups retained')
