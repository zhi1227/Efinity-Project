param([string]$VivadoBin='D:\Xilinx\Vivado\2018.3\bin')
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'test_vision6.ps1') -VivadoBin $VivadoBin -Benches @('tb_h5_palm','tb_h5_wave','tb_h5_raster','tb_h4_controls','tb_h4_skin','tb_h4_templates','tb_h4_overlay','tb_controls6','tb_matrix8','tb_vision6','tb_h5_ui','tb_i2c6','tb_health6','tb_frame_path','tb_menu_cdc6')
& (Join-Path $PSScriptRoot 'test_vision8.ps1') -VivadoBin $VivadoBin -Benches @('tb_vision8_controls','tb_vision8_fifo','tb_vision8_ddr','tb_vision8_frames','tb_vision8_faces','tb_vision8_gesture','tb_io29_freeze_ddr')
& (Join-Path $PSScriptRoot 'test_menu8_pixels.ps1') -VivadoBin $VivadoBin
& (Join-Path $PSScriptRoot 'test_cpu8.ps1') -VivadoBin $VivadoBin
& (Join-Path $PSScriptRoot 'test_epaper.ps1') -VivadoBin $VivadoBin
Write-Host 'All retained-video, Vision8, real-CPU UI and e-paper regressions passed.'
