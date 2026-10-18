param([string]$VivadoBin='D:\Xilinx\Vivado\2018.3\bin')
$ErrorActionPreference='Stop'
$buttonProject=Split-Path -Parent $PSScriptRoot
$buttonRun=Join-Path $buttonProject 'sim_button_fix'
$buttonReports=Join-Path $buttonProject 'reports/button_fix'
New-Item -ItemType Directory -Force -Path $buttonRun,$buttonReports | Out-Null
Push-Location -LiteralPath $buttonRun
try {
 $buttonSources=@('../rtl/vision8_uart.v','../rtl/vision8_controls.v','../sim/tb_vision8_key_boundary.sv','../sim/tb_vision8_controls.sv')
 & (Join-Path $VivadoBin 'xvlog.bat') '--sv' @buttonSources *> (Join-Path $buttonReports 'compile.log')
 if($LASTEXITCODE){throw 'IO28 button xvlog failed'}
 foreach($buttonBench in @('tb_vision8_key_boundary','tb_vision8_controls')){
  & (Join-Path $VivadoBin 'xelab.bat') $buttonBench '-s' $buttonBench '--relax' *> (Join-Path $buttonReports "$buttonBench.elab.log")
  if($LASTEXITCODE){throw "xelab failed: $buttonBench"}
  $buttonLog=Join-Path $buttonReports "$buttonBench.log"
  & (Join-Path $VivadoBin 'xsim.bat') $buttonBench '-runall' '-log' $buttonLog *> (Join-Path $buttonReports "$buttonBench.console.log")
  if($LASTEXITCODE){throw "xsim failed: $buttonBench"}
  $buttonResult=Get-Content -LiteralPath $buttonLog -Raw
  if($buttonResult -notmatch 'PASS:' -or $buttonResult -match 'Fatal:|Error:'){
   throw "Simulation failed: $buttonBench"
  }
  Select-String -LiteralPath $buttonLog -SimpleMatch 'PASS:' | ForEach-Object {$_.Line}
 }
} finally {Pop-Location}
