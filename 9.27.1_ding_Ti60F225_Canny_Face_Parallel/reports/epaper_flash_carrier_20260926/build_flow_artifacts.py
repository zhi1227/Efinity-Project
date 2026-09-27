from pathlib import Path
import csv
import html
import json

ROOT = Path(__file__).resolve().parent
FONT = 'Microsoft YaHei, Noto Sans CJK SC, sans-serif'
C = dict(ink='#172b46', muted='#56677c', blue='#2563eb', teal='#087f73', orange='#bd6513', red='#bf3b40', line='#cbd5e1', pale='#f4f7fb')

def esc(x):
    return html.escape(str(x), quote=True)

class SVG:
    count = 0
    def __init__(self, w, h, title, subtitle):
        self.w, self.h = w, h
        SVG.count += 1
        self.uid = f'g{SVG.count}'
        self.parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" role="img" aria-label="{esc(title)}">', '<defs>']
        for key in ['ink', 'blue', 'teal', 'orange', 'red', 'muted']:
            self.parts.append(f'<marker id="{self.uid}-arr-{key}" markerWidth="9" markerHeight="9" refX="8" refY="4.5" orient="auto-start-reverse"><path d="M0 0 L9 4.5 L0 9 Z" fill="{C[key]}"/></marker>')
        self.parts += ['</defs>', f'<rect width="{w}" height="{h}" fill="#fff"/>']
        self.text(50, 57, title, 31, bold=True)
        self.text(50, 94, subtitle, 17, color='muted')
    def text(self, x, y, text, size=21, color='ink', bold=False, anchor='start'):
        color=C.get(color, color)
        self.parts.append(f'<text x="{x}" y="{y}" font-family="{FONT}" font-size="{size}" fill="{color}" font-weight="{700 if bold else 400}" text-anchor="{anchor}">{esc(text)}</text>')
    def lines(self, x, y, lines, size=21, color='ink', bold=False, anchor='start', gap=None):
        for i,t in enumerate(lines):
            self.text(x, y+i*(gap or size*1.5), t, size, color, bold, anchor)
    def box(self, x,y,w,h, title, lines=(), color='blue', fill='#f4f7ff', size=21):
        self.parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="14" fill="{fill}" stroke="{C.get(color,color)}" stroke-width="1.6"/>')
        self.text(x+22,y+34,title,size,color,True)
        self.lines(x+22,y+66,lines,18,gap=28)
    def decision(self,x,y,w,h,lines,color='blue'):
        self.parts.append(f'<polygon points="{x+w/2},{y} {x+w},{y+h/2} {x+w/2},{y+h} {x},{y+h/2}" fill="#f4f7ff" stroke="{C[color]}" stroke-width="1.8"/>')
        self.lines(x+w/2,y+h/2-((len(lines)-1)*14)+7,lines,20,anchor='middle',gap=28)
    def edge(self, pts, color='muted', dash=False, label=None, labelpos=None):
        p=' '.join(f'{x},{y}' for x,y in pts)
        self.parts.append(f'<polyline points="{p}" fill="none" stroke="{C[color]}" stroke-width="2.2" stroke-linejoin="round" marker-end="url(#{self.uid}-arr-{color})"'+(' stroke-dasharray="7 5"' if dash else '')+'/>')
        if label and labelpos:
            self.text(*labelpos,label,16,color,bold=True)
    def footer(self, text):
        self.text(50,self.h-26,text,16,'muted')
    def save(self,name):
        data='\n'.join(self.parts+['</svg>'])
        (ROOT/(name+'.svg')).write_text(data,encoding='utf-8')
        return data

diagrams=[]
s=SVG(1600,1000,'01  图片真正走的路径：Flash → FPGA → 电子纸','这是逻辑数据方向；每条外设信号的实际线路都经过 IDC40 和底板定向缓冲。')
s.box(45,190,360,270,'W25Q32 现成模块',['存放预先编码的表情位图','标准 SPI 从设备','CS / CLK / DI：接收命令','DO：向 FPGA 返回图片数据'],color='teal',fill='#edfaf6')
s.box(600,140,400,470,'Ti60 FPGA 内部（待实现）',[],color='blue')
s.box(628,205,344,115,'RISC-V 控制程序',['选择图片地址、调度 SPI','检查状态、管理刷新间隔'],size=20)
s.box(628,349,344,87,'1～4 KiB RAM 小缓冲',['读一块，再发送一块'],size=20)
s.box(628,468,344,108,'SPI_A：读 Flash',['SPI_B：写电子纸','两组独立 CS / CLK / MOSI'],size=20)
s.box(1190,190,365,270,'5.79 英寸 B 电子纸模块',['DIN：接收图像与命令','DC：区分命令 / 数据','收到完整图后触发刷新','BUSY：返回忙闲状态'],color='orange',fill='#fff7ed')
s.edge([(600,270),(405,270)],'teal',label='① 读命令 + 地址',labelpos=(425,239))
s.text(427,303,'CS / CLK / DI',16,'teal')
s.edge([(405,395),(600,395)],'teal',label='② 图片字节 DO',labelpos=(422,377))
s.edge([(1000,270),(1190,270)],'orange',label='③ 写入命令 + 数据',labelpos=(1013,239))
s.text(1018,303,'CLK / DIN / DC / CS',15,'orange')
s.edge([(1190,395),(1000,395)],'orange',label='④ BUSY 忙闲',labelpos=(1024,377))
s.box(45,675,470,145,'开发板 → 新底板',['IDC40：36 个信号 + 电源 / 地','底板供电与信号侧为 3.3V','FPGA 侧约束仍是 1.8V LVCMOS'],size=20)
s.box(563,675,470,145,'新底板的工作',['连接器 + 两片 SN74LVC244A','GH9P 接屏；1×6 排母接 Flash','新底板无需额外 CPU 或屏升压电路'],color='teal',fill='#edfaf6',size=20)
s.box(1080,675,475,145,'剩余引脚',['11 个 IO 分给屏和 Flash','25 个 IO → J4 的 2×13 排针','其中 10 个属于按键 / 配置复用'],color='orange',fill='#fff7ed',size=20)
s.box(45,855,1510,85,'你当前图的三处改线',['DIN：IO0 → IO14；RST：IO8 → IO16；PWR：IO12 → IO22。并加入缓冲和 Flash 接口。'],color='red',fill='#fff4f4',size=21)
s.footer('画原理图时：W25 的 DO 接 FPGA 的 MISO；电子纸 DIN 接 FPGA 的另一路 MOSI，二者不要直接相连。')
diagrams.append(('01_系统数据路径','系统总览',s.save('01_系统数据路径')))

with (ROOT/'缓冲接线.csv').open(encoding='utf-8-sig',newline='') as f:
    buffers=list(csv.DictReader(f))
with (ROOT/'IDC40引脚分配.csv').open(encoding='utf-8-sig',newline='') as f:
    pins=list(csv.DictReader(f))
by_sig={r['底板信号']:r for r in pins}
by_buf={r['信号']:r for r in buffers}
order=['EPD_DIN','EPD_CLK','EPD_CS','EPD_DC','EPD_RST','EPD_BUSY','EPD_PWR','FLASH_CS','FLASH_CLK','FLASH_MOSI','FLASH_MISO']
s=SVG(1600,1280,'02  十一路信号完整连接：方向、IDC 脚号和缓冲脚号','统一位号：J1=IDC40；J2=GH9P；J3=Flash排母；U1/U2=缓冲。把你图中的电子纸连接器 U1 改名 J2。')
s.text(65,142,'开发板 / IDC 一侧',21,bold=True)
s.text(645,142,'缓冲：A 输入 → Y 输出',21,bold=True)
s.text(1130,142,'外设连接器一侧',21,bold=True)
for i,name in enumerate(order):
    p=by_sig[name];b=by_buf[name];y=162+i*76
    incoming=b['FPGA方向']=='input'
    color='teal' if name.startswith('FLASH') else 'blue'
    fill='#edfaf6' if color=='teal' else '#f4f7ff'
    s.box(50,y,430,62,f"J1-{p['IDC脚号']}   {p['原板网络']}",[],color,fill,18)
    s.text(72,y+52,f"{p['FPGA_GPIO']} / 球位 {p['FPGA球位']}   FPGA {'输入' if incoming else '输出'}",14)
    s.box(615,y,385,62,f"{b['缓冲芯片']}：输入{b['输入A脚']}脚 → 输出{b['输出Y脚']}脚",[],color,fill,19)
    s.text(637,y+52,'Y 输出后串 33Ω（预留可调整）',14)
    terminal=b['来源'] if incoming else b['串阻后去向']
    s.box(1125,y,425,62,f'{terminal}   {name}',[],color,fill,19)
    s.text(1147,y+52,'模块 → 缓冲 → FPGA' if incoming else 'FPGA → 缓冲 → 模块',14)
    if incoming:
        s.edge([(1125,y+31),(1000,y+31)],color)
        s.edge([(615,y+31),(480,y+31)],color)
    else:
        s.edge([(480,y+31),(615,y+31)],color)
        s.edge([(1000,y+31),(1125,y+31)],color)
s.box(50,1025,1500,92,'电源直连，不经过信号缓冲',['J1-29 → 3.3V → J2-1 / J3-1 / U1、U2 的20脚；J1-12、30 → 共地 → J2-2 / J3-4 / U1、U2 的10脚。'],color='orange',fill='#fff7ed',size=20)
s.box(50,1134,1500,90,'使能与未用脚',['U1/U2 的1、19脚接 BUF_nOE：10kΩ上拉，JP1短接GND启用。U2未用A脚接地，未用Y脚留空。'],color='muted',fill='#f5f7fa',size=20)
s.footer('注意：两路返回信号 BUSY / MISO 必须释放原 LCD 输出使能。缓冲脚号按 SN74LVC244A 的 PW / TSSOP-20 封装。')
diagrams.append(('02_信号连接','信号接线',s.save('02_信号连接')))

s=SVG(1600,1910,'03  一张图怎样从 W25 搬到电子纸：分块传输','设计流程，尚未实现固件。例：每次搬运1024字节；半屏方向、位序、颜色极性按5.79 B驱动编码。')
x,w,c=540,680,880
s.box(x,130,w,90,'锁定 active_image_id',['检查图片头：尺寸、格式、长度、地址范围、预期校验值'])
s.edge([(c,220),(c,260)])
s.box(x,260,w,110,'选择半屏 / 黑白或红色平面',['设置该段RAM窗口和起始位置；DC=0发写RAM命令','同一张图发完前，不用新识别结果替换正在传输的图片'])
s.edge([(c,370),(c,410)])
s.box(x,410,w,85,'计算本块长度 n = min(1024, 本段剩余字节)',['根据段描述计算 Flash 地址'])
s.edge([(c,495),(c,540)])
s.box(x,540,w,145,'SPI_A：读取 Flash',['FLASH_CS=0；DI依次发送 0x03 + 24位地址','继续提供 n×8 个时钟；从 DO/MISO 收进 RAM','命令与地址阶段的返回位丢弃；读完 FLASH_CS=1'],color='teal',fill='#edfaf6')
s.edge([(c,685),(c,730)])
s.box(x,730,w,88,'小缓冲中现在有 n 字节',['累计 CRC / 长度；Flash 已取消片选，可暂停时钟'],color='teal',fill='#edfaf6')
s.edge([(c,818),(c,865)])
s.box(x,865,w,145,'SPI_B：发送这 n 字节给屏内 RAM',['DC=1，按屏驱动的CS时序从 DIN 发出数据','屏内部RAM地址递增；暂不触发刷新','发送结束：更新段内偏移和剩余长度'],color='orange',fill='#fff7ed')
s.edge([(c,1010),(c,1050)])
s.decision(620,1050,520,145,['当前段还有未发送字节？'])
s.edge([(620,1122),(440,1122),(440,452),(540,452)],'blue',label='是：下一块',labelpos=(294,900))
s.edge([(c,1195),(c,1240)],label='否',labelpos=(900,1220))
s.decision(620,1240,520,145,['还有其他半屏 / 颜色段？'])
s.edge([(1140,1312),(1390,1312),(1390,315),(1220,315)],'orange',label='是：选择下一段',labelpos=(1245,1100))
s.edge([(c,1385),(c,1430)],label='否',labelpos=(900,1410))
s.decision(620,1430,520,145,['总长度与 CRC 均正确？'])
s.edge([(620,1502),(500,1502),(500,1640),(465,1640)],'red',label='否',labelpos=(526,1491))
s.box(50,1560,415,170,'停止本次刷新',['不要触发屏幕更新','记录错误，按策略重新初始化','下一次重传完整图片','屏内部分RAM写入不等于画面已更新'],color='red',fill='#fff4f4',size=20)
s.edge([(c,1575),(c,1625)],label='是',labelpos=(900,1605))
s.box(x,1625,w,100,'全部图像写完后，只触发一次整屏刷新',['切回命令阶段；按驱动启动更新 → 返回主状态机等待BUSY'],color='orange',fill='#fff7ed')
s.box(50,1795,1500,70,'两组SPI的职责',['SPI_A接Flash：CS、CLK、DI、DO；SPI_B接电子纸：CS、CLK、DIN，另有DC/RST/PWR/BUSY。'],color='muted',fill='#f5f7fa',size=19)
s.footer('分块传输减少 FPGA RAM；它不是电子纸局部刷新，也不会把整屏刷新时间缩短成数据传输时间。')
diagrams.append(('03_分块传图流程','传图流程',s.save('03_分块传图流程')))

s=SVG(1680,2050,'04  表情识别与电子纸刷新：并行识别，顺序换图','规划中的软件/硬件分工；表情模式14、RISC-V和电子纸驱动尚未接入当前工程。')
s.box(45,145,495,100,'视频与识别任务持续运行',['摄像头 → 单人目标 → 四表情分类','摄像头 / HDMI 不等待电子纸'],color='teal',fill='#edfaf6')
s.edge([(292,245),(292,290)],'teal')
s.box(45,290,495,130,'筛选稳定结果',['有人脸且置信度达标；连续多帧一致','无人 / 低置信度时维持当前显示','时间阈值与四类名称由应用配置'],color='teal',fill='#edfaf6')
s.edge([(292,420),(292,465)],'teal')
s.box(45,465,495,135,'跨时钟邮箱：pending_id',['只保存最新稳定结果','电子纸忙时也持续更新该邮箱','不无限排队；不改当前 active_id'],color='teal',fill='#edfaf6')
s.box(740,145,730,105,'上电与接口初始化',['9路输出 / 2路输入；CS先拉高，SPI设置Mode0','读Flash ID，核对容量与图片目录；异常进入错误处理'])
s.edge([(1105,250),(1105,315)])
s.decision(815,315,580,145,['pending有效，且与已显示图不同？'])
s.edge([(540,525),(645,525),(645,387),(815,387)],'teal',label='读取最新结果',labelpos=(558,370))
s.edge([(1395,387),(1590,387),(1590,650),(1470,650)],'muted',label='否：稍后再检查',labelpos=(1432,431))
s.box(1010,605,460,93,'主循环 / 定时调度',['不阻塞视频；稍后重新检查'],color='muted',fill='#f5f7fa',size=20)
s.edge([(1240,605),(1240,555),(1105,555),(1105,460)],'muted')
s.edge([(1105,460),(740,520),(740,710),(1105,710),(1105,750)],'blue',label='是',labelpos=(950,506))
s.decision(815,750,580,145,['屏幕空闲，且刷新间隔已满足？'])
s.edge([(1395,822),(1540,822),(1540,650),(1470,650)],'muted',label='否',labelpos=(1440,804))
s.edge([(1105,895),(1105,940)],label='是',labelpos=(1127,923))
s.box(740,940,730,110,'锁定 active_id，准备屏幕',['PWR使能 → 按驱动复位 / 初始化 → 等待就绪','检查图片头与边界；初始化等待也应带超时'])
s.edge([(1105,1050),(1105,1090)])
s.box(740,1090,730,100,'分块读 Flash，写屏内 RAM',['调用图03流程；同一次刷新只使用锁定的那张图'])
s.edge([(1105,1190),(1105,1230)])
s.decision(815,1230,580,130,['传输与校验成功？'])
s.box(45,1160,495,200,'错误处理',['CS取消片选，记录错误状态','未触发刷新时不宣称画面已改变','刷新超时则画面状态标为未知','按驱动结束 / 休眠；限次延时重试','pending继续更新，避免无限重试'],color='red',fill='#fff4f4',size=20)
s.edge([(815,1295),(540,1295)],'red',label='否',labelpos=(657,1274))
s.edge([(740,995),(595,995),(595,1210),(540,1210)],'red',label='初始化失败 / 超时',labelpos=(542,970))
s.edge([(1105,1360),(1105,1405)],label='是',labelpos=(1127,1387))
s.box(740,1405,730,105,'发整屏刷新命令',['开始异步等待；不要重复发图或中途重启刷新','屏内两个控制IC按该型号驱动协调更新'],color='orange',fill='#fff7ed')
s.edge([(1105,1510),(1105,1550)])
s.box(740,1550,730,140,'轮询同步后的 BUSY，按驱动判断刷新完成',['BUSY高表示忙；设定超过正常刷新时间的超时','等待期间：识别继续，新的结果只更新pending','未完成就返回调度，不能死循环占住所有任务'],color='orange',fill='#fff7ed')
s.edge([(740,1620),(620,1620),(620,1320),(540,1320)],'red',label='超时',labelpos=(644,1560))
s.edge([(1105,1690),(1105,1740)],label='刷新成功',labelpos=(1127,1718))
s.box(740,1740,730,130,'记录已显示图并按驱动休眠 / 关电',['displayed_id = active_id；记录完成时间','保留pending；达到刷新间隔后再检查最新结果','休眠后下次传图需重新初始化'],color='orange',fill='#fff7ed')
s.edge([(1470,1805),(1620,1805),(1620,285),(1105,285),(1105,315)],'blue',label='回到主循环',labelpos=(1499,1200))
s.box(45,1475,495,180,'时间预算',['当前屏整屏刷新典型约24～25秒','SPI 1MHz时两次搬运纯载荷约0.87秒','总等待另含初始化、排队与间隔','不能按“识别出一次就立即刷一次”设计'],color='orange',fill='#fff7ed',size=20)
s.box(45,1765,610,108,'刷新频率策略',['官方Wiki建议刷新间隔至少180秒。','刷新耗时与允许的重复刷新间隔是两个不同参数。'],color='muted',fill='#f5f7fa',size=20)
s.footer('分支逻辑为设计方案，需移植该屏驱动后实测；BUSY完成、故障恢复与供电时序不能仅用固定延时代替。')
diagrams.append(('04_识别刷新流程','识别刷新',s.save('04_识别刷新流程')))

def table(headers, rows, searchable=False):
    attr=' class="pin-table"' if searchable else ''
    return '<div class="table-scroll"><table'+attr+'><thead><tr>'+''.join('<th>'+esc(h)+'</th>' for h in headers)+'</tr></thead><tbody>'+''.join('<tr>'+''.join('<td>'+esc(v)+'</td>' for v in r)+'</tr>' for r in rows)+'</tbody></table></div>'

epd=[['1','VCC','29','3.3V','电源'],['2','GND','12 / 30','GND','地'],['3','DIN','17','IO14','输出'],['4','CLK','3','IO2','输出'],['5','CS','5','IO4','输出'],['6','DC','7','IO6','输出'],['7','RST','19','IO16','输出'],['8','BUSY','13','IO10','输入'],['9','PWR','25','IO22','输出']]
flash=[['1','VCC','29','3.3V','电源'],['2','CS','27','IO24','输出'],['3','DO / MISO','24','IO21','输入'],['4','GND','12 / 30','GND','地'],['5','CLK','26','IO23','输出'],['6','DI / MOSI','23','IO20','输出']]
nav=''.join(f'<button class="tab" data-target="d{i}" aria-selected="{str(i==0).lower()}">{esc(t)}</button>' for i,(_,t,_) in enumerate(diagrams))+'<button class="tab" data-target="pins" aria-selected="false">全部引脚</button><button class="tab" data-target="notes" aria-selected="false">画图清单</button>'
panels=[]
for i,(name,title,svg) in enumerate(diagrams):
    intro=['Flash需要FPGA发送读命令才返回数据；FPGA随后用另一组SPI发送给电子纸。图中的RISC-V和新外设驱动均为后续实现。','每行按箭头接线。先将当前图中的电子纸接口U1改为J2，把U1/U2留给缓冲芯片；不要让缓冲前后使用相同网名。','以1KiB缓存循环搬运。读取Flash不等于刷屏：所有颜色/半屏段写完并校验后才触发一次整屏更新。','识别和显示解耦。忙时只保存最新结果，不中断当前刷新，不积累无限待显示队列。'][i]
    panels.append(f'<section id="d{i}" class="panel {"active" if i==0 else ""}"><h2>{esc(title)}</h2><p>{esc(intro)}</p><div class="toolbar"><button data-zoom="-">缩小</button><button data-zoom="+">放大</button><button data-zoom="reset">适合宽度</button><a href="{name}.svg" download>下载SVG</a><a href="{name}.png" download>下载PNG</a></div><div class="diagram">{svg}</div></section>')
allrows=[[r['IDC脚号'],r['原板网络'].replace('User_3V3_',''),r['底板信号'],r['去向'],r['FPGA球位'],r['当前工程占用'],r['说明']] for r in pins]
brows=[[b['信号'],b['来源'],b['缓冲芯片'],b['输入A脚'],b['输出Y脚'],b['串阻后去向']] for b in buffers]
panels.append('<section id="pins" class="panel"><h2>全部引脚规划</h2><p>方向相对FPGA。信号经缓冲；电源和地直接连接。J3按照所给模块元件面，从VCC方焊盘开始编号。</p><h3>J2：GH9P电子纸</h3>'+table(['J2脚','信号','IDC脚','网络','方向'],epd)+'<h3>J3：Flash模块排母</h3>'+table(['J3脚','模块丝印','IDC脚','网络','方向'],flash)+'<h3>J1：IDC40完整分配</h3><label class="filter">查引脚 / 信号 / 球位 <input id="filter" placeholder="例如 IO14、MISO、K2、配置Flash" /></label><p id="count">共40行</p>'+table(['IDC脚','原网络','分配信号','去向','FPGA球位','现有工程占用','备注'],allrows,True)+'<h3>U1/U2：缓冲信号脚</h3>'+table(['信号','来源','器件','输入A脚','输出Y脚','输出串33Ω后去向'],brows)+'<p>两片20脚接3.3V、10脚接地；1/19脚接BUF_nOE（10kΩ上拉，JP1短接GND启用）。U2未用A脚8/11/13/15/17接地，Y脚12/9/7/5/3留空。</p></section>')
notes='''<section id="notes" class="panel"><h2>按你的当前原理图修改</h2><ol><li>将电子纸连接器位号U1改为J2；DIN从IO0改IO14，RST从IO8改IO16，PWR从IO12改IO22。</li><li>加入两片SN74LVC244APWR（PW/TSSOP-20），按图02区分9路输出和2路输入。HOST侧与模块侧分开命名。</li><li>加入J3六针排母：1=VCC，2=CS，3=DO，4=GND，5=CLK，6=DI。针距按实物确认。</li><li>J4用2×13排针引出25路剩余IO和1路GND；J5引出3.3V/GND/5V/GND。复用脚明确标注。</li><li>加入电源去耦、串阻位置、默认电平电阻和JP1。U1/U2各100nF；IDC入口22µF+100nF；屏接口10µF+100nF；Flash接口1µF+100nF。</li><li>现有LCD端口需释放，特别是BUSY和MISO必须取消原输出使能。当前位流不是本底板的测试程序。</li></ol><h3>先存图，再运行</h3><p>PC上把图片转为792×272黑白红位平面，按半屏行字节对齐、位序与驱动发送顺序编码；存入Flash并回读校验。原PNG/JPG不能直接当屏幕数据发出。四类名称可映射到任意图片槽。</p><h3>建议存储分区（设计约定）</h3><p>0x000000～0x00FFFF预留目录/版本；10个图片槽从0x010000开始，每槽64KiB。图片槽i的地址=0x010000+i×0x10000。可预留256字节头部，记录长度、格式、各段偏移与CRC。原始双平面约53,856字节，半屏按行补齐后可为54,400字节，均可放入一个槽。具体存储布局应与驱动/转换器共同确定。</p><h3>缓冲与供电补充</h3><p>串阻初值33Ω仅作调试起点。BUF_nOE默认上拉禁用，确认正确固件后插JP1启用。模块侧CS/RST可100kΩ上拉，PWR可100kΩ下拉；返回BUSY/MISO输入可100kΩ下拉，若模块已有拉电阻需核算。不要在屏TXB信号上增加强上拉。详细电阻与网络连接见同目录Markdown方案。</p><h3>确认边界</h3><p>本成果是接线规划与详细流程图，未生成可投板CAD文件，也未修改RTL或刷写硬件。模块针距、GH连接器与线束方向、供电压降和实际SPI波形仍需核实。当前屏典型整屏刷新约24～25秒，厂商建议刷新间隔至少180秒，二者不是同一个参数。</p><h3>文件与依据</h3><p><a href="底板原理图接线方案.md">详细原理图接线方案</a> · <a href="IDC40引脚分配.csv">40针CSV</a> · <a href="缓冲接线.csv">缓冲CSV</a></p><p>板卡/核心板/电子纸本地原理图与当前Ti60_Demo.peri.xml；<a href="https://www.waveshare.com/wiki/5.79inch_e-Paper_Module_(B)_Manual">微雪该型号手册</a>；<a href="https://www.winbond.com/resource-files/W25Q32JV%20RevJ%2012242024%20Plus.pdf">W25Q32JV数据手册</a>；<a href="https://www.ti.com/lit/ds/symlink/sn74lvc244a.pdf">SN74LVC244A数据手册</a>。</p></section>'''
panels.append(notes)
css='''*{box-sizing:border-box}body{margin:0;color:#172b46;background:#f0f4f8;font:16px/1.65 "Microsoft YaHei",sans-serif}header{padding:28px 36px 18px;background:#152c4a;color:white}header h1{margin:0;font-size:27px}header p{margin:8px 0 0;color:#d6e2ef}nav{position:sticky;top:0;z-index:10;display:flex;gap:8px;flex-wrap:wrap;padding:14px 28px;background:#fff;border-bottom:1px solid #d6e0ea}button,a{touch-action:manipulation}button{font:inherit;cursor:pointer;border:1px solid #ccd7e2;border-radius:8px;background:#fff;padding:7px 15px;color:#26415d}button[aria-selected=true]{background:#2563eb;color:#fff;border-color:#2563eb}main{padding:22px;max-width:1900px;margin:auto}.panel{display:none;background:#fff;padding:24px;border-radius:14px;box-shadow:0 3px 18px #1b345010}.panel.active{display:block}h2{font-size:24px;margin:0 0 10px}h3{font-size:19px;margin-top:30px}p{margin:10px 0 18px}.toolbar{display:flex;align-items:center;gap:12px;margin:16px 0}.toolbar a,a{color:#215ccc}.diagram{overflow:auto;border:1px solid #dce4ed;border-radius:10px;background:#fff}.diagram svg{display:block;width:100%;height:auto;max-width:none}.table-scroll{overflow:auto}table{width:100%;border-collapse:collapse;font-size:14px}th,td{text-align:left;padding:10px 12px;border:1px solid #dfe6ee;vertical-align:top}th{background:#eff4fa;white-space:nowrap}tbody tr:nth-child(even){background:#fafcfe}.filter{display:flex;align-items:center;gap:14px;font-weight:700}input{padding:10px;width:390px;border:1px solid #cbd5e1;border-radius:8px;font:inherit}li{margin:13px 0}footer{padding:16px 36px;color:#617386}@media(max-width:700px){header,main{padding:16px}nav{padding:10px}.panel{padding:12px}.toolbar{flex-wrap:wrap}h1{font-size:22px!important}.filter{display:block}input{width:100%}}@media print{body{background:white}header{color:#172b46;background:white}nav,.toolbar,.filter,#count,footer{display:none}.panel{display:block;box-shadow:none;border-radius:0;padding:0;break-before:page}.panel:first-child{break-before:auto}main{padding:0}.diagram{overflow:visible;border:0}.diagram svg{width:100%!important}tr{break-inside:avoid}}'''
js='''document.querySelectorAll('.tab').forEach(b=>b.addEventListener('click',()=>{document.querySelectorAll('.tab').forEach(t=>t.setAttribute('aria-selected',String(t===b)));document.querySelectorAll('.panel').forEach(p=>p.classList.toggle('active',p.id===b.dataset.target));}));document.querySelectorAll('[data-zoom]').forEach(b=>b.addEventListener('click',()=>{const svg=b.closest('.panel').querySelector('svg');let z=Number(svg.dataset.zoom||1);z=b.dataset.zoom==='reset'?1:Math.max(.5,Math.min(3,z+(b.dataset.zoom==='+'?.25:-.25)));svg.dataset.zoom=z;svg.style.width=(100*z)+'%';}));document.getElementById('filter').addEventListener('input',e=>{const q=e.target.value.trim().toLowerCase();let n=0;document.querySelectorAll('.pin-table tbody tr').forEach(r=>{const show=r.textContent.toLowerCase().includes(q);r.hidden=!show;if(show)n++;});document.getElementById('count').textContent='显示 '+n+' / 40 行';});'''
page='<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Ti60电子纸底板：引脚与数据流程</title><style>'+css+'</style></head><body><header><h1>Ti60 × W25Q32 × 电子纸</h1><p>IDC40转接底板 · 完整引脚分配 · 分块传图 · 表情刷新调度　/　2026-09-26</p></header><nav>'+nav+'</nav><main>'+''.join(panels)+'</main><footer>离线文件，无外部脚本依赖。SVG可放大、PNG可分享；打印时输出全部内容。</footer><script>'+js+'</script></body></html>'
(ROOT/'接线与流程总览.html').write_text(page,encoding='utf-8')
(ROOT/'图件清单.json').write_text(json.dumps([{'name':n,'title':t} for n,t,_ in diagrams],ensure_ascii=False,indent=2),encoding='utf-8')
print('Built 4 SVG diagrams and offline HTML overview.')
