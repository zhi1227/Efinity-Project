param([string]$VivadoBin='D:\Xilinx\Vivado\2018.3\bin')
$ErrorActionPreference='Stop'
$buttonProject=Split-Path -Parent $PSScriptRoot
New-Item -ItemType Directory -Force -Path (Join-Path $buttonProject 'reports/vision8') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $buttonProject 'reports/ui_refresh') | Out-Null
& (Join-Path $PSScriptRoot 'test_io28_button.ps1') -VivadoBin $VivadoBin
& (Join-Path $PSScriptRoot 'test_io28_counterexamples.ps1') -VivadoBin $VivadoBin
& (Join-Path $PSScriptRoot 'test_pip_pixels.ps1') -VivadoBin $VivadoBin
& (Join-Path $PSScriptRoot 'test_all.ps1') -VivadoBin $VivadoBin
& (Join-Path $PSScriptRoot 'test_gesture_roi.ps1') -VivadoBin $VivadoBin
Write-Host 'IO28 boundary, PiP pixels, retained features and ROI regressions passed; no hardware programmed.'
