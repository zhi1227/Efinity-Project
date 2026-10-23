# Fresh optimized-copy regressions. Does not compile/program FPGA or modify originals.
param([string]$VivadoBin='D:\Xilinx\Vivado\2018.3\bin',[string]$Toolchain='D:\Efinity\efinity-riscv-ide-2025.1\toolchain\bin')
$ErrorActionPreference='Stop'
$regProject=Split-Path -Parent $PSScriptRoot
$regReport=Join-Path $regProject 'reports/ramopt_regression'
New-Item -ItemType Directory -Force -Path $regReport | Out-Null
$regStarted=(Get-Date).ToUniversalTime().ToString('o')
$regResults=@()
$regGroupSaved=$env:RAMOPT_GROUP
$regRunSaved=$env:RAMOPT_RUN
$regVivadoSaved=$env:RAMOPT_VIVADO
try {
 $env:RAMOPT_GROUP='final_suite';$env:RAMOPT_RUN='sim_ramopt_final';$env:RAMOPT_VIVADO=$VivadoBin
 & python -X utf8 (Join-Path $PSScriptRoot 'test_ramopt_regression.py')
 if($LASTEXITCODE){throw 'Current-source retained-function/five-gesture suite failed'}
 $regResults+=@{entry='test_ramopt_regression.py';status='PASS'}
 foreach($regScript in @('test_ramopt_buffers.ps1','test_ramopt_wide_lines.ps1','test_ramopt_shared_font.ps1','test_ramopt_coordinates.ps1','test_menu8_pixels.ps1','test_cache_stress.ps1','test_cpu8.ps1','test_epaper.ps1')) {
  $regStepStart=Get-Date
  if($regScript -eq 'test_cache_stress.ps1') { & (Join-Path $PSScriptRoot $regScript) -VivadoBin $VivadoBin -Toolchain $Toolchain }
  else { & (Join-Path $PSScriptRoot $regScript) -VivadoBin $VivadoBin }
  if($LASTEXITCODE){throw "Regression failed: $regScript"}
  $regResults+=@{entry=$regScript;status='PASS';seconds=((Get-Date)-$regStepStart).TotalSeconds}
 }
 @{started_utc=$regStarted;completed_utc=(Get-Date).ToUniversalTime().ToString('o');vivado=$VivadoBin;groups=$regResults;hardware_test='Not performed'} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $regReport 'delivery_run.json') -Encoding UTF8
 Write-Host 'PASS: current five-gesture, video, buttons, DDR, all-address/font, RAM equivalence, UI, real CPU and EPD suites.'
} finally {$env:RAMOPT_GROUP=$regGroupSaved;$env:RAMOPT_RUN=$regRunSaved;$env:RAMOPT_VIVADO=$regVivadoSaved}
