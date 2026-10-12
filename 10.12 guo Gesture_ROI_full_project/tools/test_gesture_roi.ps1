param([string]$VivadoBin='E:\Xilinx\Vivado\2019.2\bin')
$ErrorActionPreference='Stop'
& "$PSScriptRoot/test_vision6.ps1" -VivadoBin $VivadoBin -Benches @('tb_gesture_roi','tb_h4_overlay','tb_h5_raster','tb_h5_ui','tb_threshold_ui')
