param([string]$VivadoBin='D:\Xilinx\Vivado\2018.3\bin')
$ErrorActionPreference='Stop'
$inlineProject=Split-Path -Parent $PSScriptRoot
$inlineRun=Join-Path $inlineProject 'sim_inline_controls'
$inlineReports=Join-Path $inlineProject 'reports/inline_threshold/controls'
New-Item -ItemType Directory -Force -Path $inlineRun,$inlineReports | Out-Null
$inlineSources=@('rtl/vision8_uart.v','rtl/vision8_controls.v','sim/tb_vision8_key_boundary.sv','sim/tb_inline_controls.sv')
$inlineInputs=@($inlineSources | ForEach-Object { $inlineFile=Join-Path $inlineProject $_; [pscustomobject]@{path=$_;sha256=(Get-FileHash -LiteralPath $inlineFile -Algorithm SHA256).Hash.ToLower()} })
$inlineInputs | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $inlineReports 'inputs.json') -Encoding UTF8
Push-Location -LiteralPath $inlineRun
try {
 & (Join-Path $VivadoBin 'xvlog.bat') '--sv' @($inlineSources | ForEach-Object {Join-Path $inlineProject $_}) *> (Join-Path $inlineReports 'compile.log')
 if($LASTEXITCODE){throw 'Inline controls xvlog failed'}
 foreach($inlineBench in @('tb_vision8_key_boundary','tb_inline_controls')){
  & (Join-Path $VivadoBin 'xelab.bat') $inlineBench '-s' $inlineBench '--relax' *> (Join-Path $inlineReports "$inlineBench.elab.log")
  if($LASTEXITCODE){throw "xelab failed: $inlineBench"}
  $inlineLog=Join-Path $inlineReports "$inlineBench.log"
  & (Join-Path $VivadoBin 'xsim.bat') $inlineBench '-runall' '-log' $inlineLog *> (Join-Path $inlineReports "$inlineBench.console.log")
  if($LASTEXITCODE){throw "xsim failed: $inlineBench"}
  $inlineResult=Get-Content -LiteralPath $inlineLog -Raw
  $inlineMarker=if($inlineBench -eq 'tb_inline_controls'){'PASS: INLINE_CONTROLS_COMPLETE'}else{'PASS: vision8_key same-edge NBA context changes mask pending short/long before a new context can consume them'}
  if($inlineResult -notmatch [regex]::Escape($inlineMarker) -or $inlineResult -match 'Fatal:|Error:' -or $inlineResult -notmatch '\$finish called'){
   throw "Simulation did not complete: $inlineBench"
  }
  Select-String -LiteralPath $inlineLog -SimpleMatch 'PASS:' | ForEach-Object {$_.Line}
 }
} finally {Pop-Location}
