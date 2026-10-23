# 本轮迭代与未选用证据

- 原版负向测试 `tb_capture_exit_regression_original` 按预期失败，复现离开四帧仍保持抓拍锁。负向测试的 PASS 表示成功复现缺陷，不表示原版正确。
- 首批实现修复了抓拍退出、完整帧检查及模式/按键，但 PiP 专项测试发现其欠载计数被非四帧状态持续清零。最终代码只在明确清空/离开四帧期间清理该计数。
- 加大写通道背压后发现摄像头 FIFO 空填充拍使 WDATA 在停顿时变化（日志明确 owner=1）。最终 `vision8_ddr` 加入已呈现拍保持；不是修改摄像头初始化、FIFO IP 或 DDR IP。
- 背压测试最初只等待 FIFO full 后固定 25 拍即解除，可能处于行消隐，没有真正阻挡下一次有效采样。因此不能要求该输入必然报错。最终错误注入保持到实际 `snap_bad`，再恢复总线；确认失败不发布和正常重新抓拍。
- 首次 720p 压力用例在 `wait(!busy)` 的同一仿真事件中观察目录，出现完成/发布状态观察竞争。最终测试在后续稳定时钟沿检查，另加 RAW 相同 VS 相位回归，再执行完整 720p 测试。未将首次未完成的运行当成通过证据。
- `capturefix_20261020_final1` 完整构建曾通过，但它在上述补充修正之前，不是最终选择。仅 `reports/capture_fix/selected_build.json` 指向的源码匹配构建可用于本次交付。
- 所有未通过或中途编译失败的日志保留以供追踪。正式验收使用 `verify_capturefix_delivery.py` 指定的最终测试、输入哈希与结果；旧 `reports/inline_threshold`、`reports/ramopt` 和 original_outflow 是继承历史。
- 内存压力隔离测试使用真实生产 RTL 仲裁与 FIFO，以及仿真的 AXI 存储模型，不等同于板上 DDR、MIPI、电气或显示链路实测。
