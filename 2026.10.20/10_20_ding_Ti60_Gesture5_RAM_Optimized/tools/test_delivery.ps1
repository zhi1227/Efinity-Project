# ding, 2026-10-15. Full software regression; does not program the board.
param([string]$VivadoBin='D:\Xilinx\Vivado\2018.3\bin')
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$report=Join-Path $project 'reports/rgb_balance'
New-Item -ItemType Directory -Force -Path $report | Out-Null
@{started_utc=(Get-Date).ToUniversalTime().ToString('o');entrypoint='tools/test_delivery.ps1'} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $report 'tests_started.json') -Encoding UTF8
& (Join-Path $PSScriptRoot 'test_all.ps1') -VivadoBin $VivadoBin
& (Join-Path $PSScriptRoot 'test_gesture_roi.ps1') -VivadoBin $VivadoBin
& (Join-Path $PSScriptRoot 'test_rgb_balance.ps1') -VivadoBin $VivadoBin
& (Join-Path $PSScriptRoot 'test_rgb_balance.ps1') -VivadoBin $VivadoBin -Defines @('RGB_BALANCE_ENABLE=0') -RunName 'configured_disabled'
& (Join-Path $PSScriptRoot 'test_rgb_balance.ps1') -VivadoBin $VivadoBin -Defines @('RGB_BALANCE_CENTER_R=300','RGB_BALANCE_CENTER_G=128','RGB_BALANCE_CENTER_B=0','RGB_BALANCE_EDGE_R=1024','RGB_BALANCE_EDGE_G=768','RGB_BALANCE_EDGE_B=600') -RunName 'configured_custom'
& (Join-Path $PSScriptRoot 'test_camera_fifo_endian.ps1') -VivadoBin $VivadoBin
Write-Host 'All retained features, ROI, RGB balance and real vendor FIFO integration passed.'
