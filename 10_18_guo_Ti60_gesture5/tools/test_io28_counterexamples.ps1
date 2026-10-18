param(
 [string]$VivadoBin='D:\Xilinx\Vivado\2018.3\bin',
 [string]$OriginalCore='',
 [string]$FirstFixCore=''
)
$ErrorActionPreference='Stop'
$buttonProject=Split-Path -Parent $PSScriptRoot
if(!$OriginalCore){$OriginalCore=Join-Path $buttonProject 'reference/button_fix_counterexamples/original_vision8_controls.v'}
if(!$FirstFixCore){$FirstFixCore=Join-Path $buttonProject 'reference/button_fix_counterexamples/first_fix_vision8_controls.v'}
$buttonReports=Join-Path $buttonProject 'reports/button_fix'
$buttonCases=@(
 @{Name='negative_original_core';Source=$OriginalCore;Bench='tb_vision8_key_boundary';Failure='Fatal: short and long overlap'},
 @{Name='negative_pending_context_core';Source=$FirstFixCore;Bench='tb_vision8_key_boundary';Failure='Fatal: same-edge context change leaked pending long'},
 @{Name='negative_pending_context_controls';Source=$FirstFixCore;Bench='tb_vision8_controls';Failure='Fatal: page close leaked old-context pending PiP long'}
)
foreach($buttonCase in $buttonCases){
 $buttonName=$buttonCase.Name
 $buttonRun=Join-Path $buttonProject "sim_button_fix/$buttonName"
 New-Item -ItemType Directory -Force -Path $buttonRun,$buttonReports | Out-Null
 $buttonSaved=Join-Path $buttonRun 'vision8_controls_before.v'
 Copy-Item -LiteralPath $buttonCase.Source -Destination $buttonSaved
 $buttonBench=Join-Path $buttonProject ('sim/'+$buttonCase.Bench+'.sv')
 Push-Location -LiteralPath $buttonRun
 try {
  & (Join-Path $VivadoBin 'xvlog.bat') '--sv' $buttonSaved (Join-Path $buttonProject 'rtl/vision8_uart.v') $buttonBench *> (Join-Path $buttonReports "$buttonName.compile.log")
  if($LASTEXITCODE){throw "Negative-control compile failed: $buttonName"}
  & (Join-Path $VivadoBin 'xelab.bat') $buttonCase.Bench '-s' $buttonName '--relax' *> (Join-Path $buttonReports "$buttonName.elab.log")
  if($LASTEXITCODE){throw "Negative-control elaboration failed: $buttonName"}
  $buttonLog=Join-Path $buttonReports "$buttonName.log"
  & (Join-Path $VivadoBin 'xsim.bat') $buttonName '-runall' '-log' $buttonLog *> (Join-Path $buttonReports "$buttonName.console.log")
  $buttonText=Get-Content -LiteralPath $buttonLog -Raw
  if(-not $buttonText.Contains($buttonCase.Failure)){throw "Targeted expected failure missing: $buttonName"}
  [ordered]@{
   result='EXPECTED_FAILURE_OBSERVED';expected_failure=$buttonCase.Failure
   original_source=$buttonCase.Source
   original_source_sha256=(Get-FileHash -LiteralPath $buttonCase.Source -Algorithm SHA256).Hash
   saved_source=$buttonSaved;saved_source_sha256=(Get-FileHash -LiteralPath $buttonSaved -Algorithm SHA256).Hash
   testbench=$buttonCase.Bench;testbench_sha256=(Get-FileHash -LiteralPath $buttonBench -Algorithm SHA256).Hash
   log=$buttonLog;board_programmed=$false
  } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $buttonReports "$buttonName.json") -Encoding utf8
  Write-Output "PASS: expected failure reproduced: $buttonName"
 } finally {Pop-Location}
}
