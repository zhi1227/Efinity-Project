param([string]$VivadoBin='E:\Xilinx\Vivado\2019.2\bin')
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'test_vision6.ps1') -VivadoBin $VivadoBin -Benches @(
 'tb_threshold_controls','tb_threshold_commit','tb_threshold_ui',
 'tb_controls6','tb_h4_controls','tb_menu_render','tb_menu_cdc6','tb_vision6','tb_h5_ui')
