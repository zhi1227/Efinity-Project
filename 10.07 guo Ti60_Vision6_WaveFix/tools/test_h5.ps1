param([string]$VivadoBin='E:\Xilinx\Vivado\2019.2\bin')
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'test_vision6.ps1') -VivadoBin $VivadoBin -Benches @(
 'tb_h5_palm',
 'tb_h5_wave',
 'tb_h5_raster',
 'tb_h4_controls',
 'tb_h4_skin',
 'tb_h4_templates',
 'tb_h4_overlay',
 'tb_controls6',
 'tb_matrix8',
 'tb_menu_render',
 'tb_vision6',
 'tb_h5_ui')
