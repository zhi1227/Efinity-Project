param([string]$VivadoBin='D:\Xilinx\Vivado\2018.3\bin',[string[]]$Benches=@('tb_vision8_controls','tb_vision8_fifo'))
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$run=Join-Path $project 'sim_vision8'
New-Item -ItemType Directory -Force -Path $run | Out-Null
Push-Location $run
try {
 $sources=@('../src/parallel/face_grid_regions.v','../rtl/vision8_count_filter.v','../rtl/vision8_uart.v','../rtl/vision8_controls.v','../rtl/vision8_fifo.v','../rtl/vision8_ascii.v','../rtl/vision8_frames.v','../rtl/vision8_slots.v','../rtl/vision8_base_axi.v','../rtl/vision8_ddr.v','../ip/W0_FIFO_8/W0_FIFO_8.sv','../ip/R0_FIFO_16/R0_FIFO_16.sv')
 if($Benches -contains 'tb_vision8_gesture'){
  [xml]$proj=Get-Content -LiteralPath (Join-Path $project 'Ti60_Demo.xml')
  $sources+=@($proj.project.design_info.design_file | ForEach-Object {$_.name} | Where-Object {$_ -like 'src/vision/*' -or $_ -like 'src/face/*' -or $_ -like 'src/parallel/*' -or $_ -like 'src/gesture/*' -or $_ -like 'rtl/*'} | ForEach-Object {"../$_"})
  $sources=@($sources | Select-Object -Unique)
 }
 $tb=@($Benches | ForEach-Object {"../sim/$_.sv"})
 if($Benches -contains 'tb_io29_freeze_ddr'){$tb+='../sim/tb_vision8_ddr.sv'}
 & (Join-Path $VivadoBin 'xvlog.bat') '--sv' '-i' '../src/parallel' @sources @tb *> '../reports/vision8/compile.log'
 if($LASTEXITCODE){throw 'Vision8 xvlog failed'}
 foreach($bench in $Benches){
  & (Join-Path $VivadoBin 'xelab.bat') $bench '-s' $bench '--relax' *> "../reports/vision8/$bench.elab.log"
  if($LASTEXITCODE){throw "xelab failed: $bench"}
  & (Join-Path $VivadoBin 'xsim.bat') $bench '-runall' '-log' "../reports/vision8/$bench.log" *> "../reports/vision8/$bench.console.log"
  if($LASTEXITCODE){throw "xsim failed: $bench"}
  if(!(Select-String -LiteralPath "../reports/vision8/$bench.log" -SimpleMatch 'PASS:')){throw "No PASS: $bench"}
  if(Select-String -LiteralPath "../reports/vision8/$bench.log" -Pattern 'Fatal:|Error:'){throw "Simulation failed: $bench"}
  Write-Host "Passed: $bench"
 }
} finally {Pop-Location}
