param([string]$VivadoBin='E:\Xilinx\Vivado\2019.2\bin')
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
New-Item -ItemType Directory -Force -Path (Join-Path $project 'reports/gesture5') | Out-Null
$benches=@('tb_h4_templates','tb_h4_controls','tb_matrix8','tb_h5_palm','tb_h5_wave','tb_vision8_gesture','tb_h4_overlay','tb_roi_shared_overlay','tb_gesture5_rgb','tb_gesture5_ui','tb_h5_raster')
$started=Get-Date
& (Join-Path $PSScriptRoot 'test_vision6.ps1') -VivadoBin $VivadoBin -Benches $benches
if($LASTEXITCODE){throw 'Gesture regression failed'}
$tests=@($benches | ForEach-Object {@{bench=$_;status='PASS';log="reports/$_.log"}})
@{started_utc=$started.ToUniversalTime().ToString('o');completed_utc=(Get-Date).ToUniversalTime().ToString('o');tests=$tests;hardware_validation='not performed'} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $project 'reports/gesture5/simulation_results.json') -Encoding UTF8
Write-Host 'PASS: five-gesture regression suite'
