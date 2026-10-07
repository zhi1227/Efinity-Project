param([string]$VivadoBin='E:\Xilinx\Vivado\2019.2\bin',[string[]]$Benches=@('tb_vision6','tb_controls6','tb_i2c6','tb_menu_render'))
$ErrorActionPreference='Stop'
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
 [xml]$proj=Get-Content -LiteralPath 'Ti60_Demo.xml'
 $sources=@($proj.project.design_info.design_file | ForEach-Object {$_.name} | Where-Object {$_ -like 'src/vision/*' -or $_ -like 'src/face/*' -or $_ -like 'src/parallel/*' -or $_ -like 'src/gesture/*' -or $_ -like 'rtl/*' -or $_ -like 'src/cmos_i2c/*'})
 $benchFiles=@($Benches | ForEach-Object {"sim/$_.sv"})
 & (Join-Path $VivadoBin 'xvlog.bat') '--sv' '-i' 'src/parallel' @sources 'src/axi/axi4_ctrl.v' 'src/axi/frame_buffer_select.v' @benchFiles 2>&1 | Tee-Object 'reports/xvlog_vision6.log'
 if($LASTEXITCODE){throw 'xvlog failed'}
 foreach($bench in $Benches){
  & (Join-Path $VivadoBin 'xelab.bat') $bench '-s' $bench '--relax' 2>&1 | Tee-Object "reports/$bench.elab.log"
  if($LASTEXITCODE){throw 'xelab failed'}
  & (Join-Path $VivadoBin 'xsim.bat') $bench '-runall' '-log' "reports/$bench.log"
  if($LASTEXITCODE){throw 'xsim failed'}
  if(!(Select-String -LiteralPath "reports/$bench.log" -SimpleMatch 'PASS:')){throw "No PASS: $bench"}
  if(Select-String -LiteralPath "reports/$bench.log" -Pattern 'Fatal:|Error:'){throw "Simulation failed: $bench"}
 }
} finally {Pop-Location}
