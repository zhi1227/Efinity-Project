# 五手势 Vision8 四键与模式内阈值版（2026-10-20）

在 Efinity 打开本目录 **Ti60_Demo.xml**。完整说明见 [README_4Key_InlineThreshold.md](README_4Key_InlineThreshold.md)。

本目录从同日期的 10_20_ding_Ti60_Gesture5_RAM_Optimized 完整独立复制，原工程保留。保留八模式和五手势，删除独立阈值页，模式2～5就地显示一个T及STEP：Canny默认80（内部40/80），红边默认40，赛博默认24。模式2/5共享Canny参数，其他两组独立保存。实时T/STEP显示在LVDS菜单，HDMI实时画面不新增数字；HDMI四帧标签显示保存时T。

四个外接键全部低有效。IO28短按下一模式；IO29冻结或四帧保存；IO34边缘模式减T、长按换步长，手势模式录入/确认，四帧模式换算法；IO35边缘模式加T、长按恢复当前算法默认。IO28长按仍只在模式2～4开关PiP。板载K1/K2暂不使用；新增两键尚未确定管脚，不添加悬空端口。

最终验收见 reports/inline_threshold/delivery_audit.json，实际构建见同目录 selected_build.json，UI/字库专用结果在 reports/fourkey。继承的RAM优化报告、旧日志和旧bit属于原版历史证据，不能代替本轮验证。未执行上板实测，不自动下载FPGA或写Flash。

字体重新生成后必须执行频率索引压缩；不要运行历史prepare覆盖脚本。命令见完整说明。

<!-- INLINE_FINAL_RESULTS -->

本轮32项验收全部PASS；7帧720p共6,451,200算法有效像素与原版一致，另有95项四键控制、23项原功能回归及真实CPU/电子纸完整仿真。新完整构建：XLR 52399、RAM184、DSP39，setup/hold +0.298/+0.026ns。当前bit/hex已选入outflow，未上板下载。详见完整说明的结果表和已知物理接口告警。

<!-- /INLINE_FINAL_RESULTS -->
