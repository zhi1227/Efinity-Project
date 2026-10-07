param([string]$VivadoBin='E:\Xilinx\Vivado\2019.2\bin')
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'test_vision6.ps1') -VivadoBin $VivadoBin -Benches @(
 'tb_h4_controls','tb_h4_skin','tb_h4_templates','tb_h4_raster',
 'tb_h3_stability','tb_h4_overlay','tb_controls6','tb_candidate_filter',
 'tb_plus_tracking','tb_ep1_gesture','tb_matrix8','tb_menu_render','tb_vision6','tb_h4_ui')
