param([string]$VivadoBin='D:\Xilinx\Vivado\2018.3\bin')
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$run=Join-Path $project 'sim_pip_pixels'
$report=Join-Path $project 'reports/button_fix/pip_pixels'
New-Item -ItemType Directory -Force -Path $run,$report | Out-Null
Push-Location $run
try {
 $sources=@('../rtl/vision8_ascii.v','../rtl/vision8_frames.v','../sim/tb_vision8_frames.sv')
 & (Join-Path $VivadoBin 'xvlog.bat') '--sv' @sources *> (Join-Path $report 'compile.log')
 if($LASTEXITCODE){throw 'PiP pixel xvlog failed'}
 & (Join-Path $VivadoBin 'xelab.bat') 'tb_vision8_frames' '-s' 'pip_pixels' '--relax' *> (Join-Path $report 'elab.log')
 if($LASTEXITCODE){throw 'PiP pixel xelab failed'}
 & (Join-Path $VivadoBin 'xsim.bat') 'pip_pixels' '-runall' '-log' (Join-Path $report 'tb_vision8_frames.log') *> (Join-Path $report 'console.log')
 if($LASTEXITCODE){throw 'PiP pixel xsim failed'}
 $log=Join-Path $report 'tb_vision8_frames.log'
 if(!(Select-String -LiteralPath $log -SimpleMatch 'PASS:')){throw 'No PiP pixel PASS'}
 if(Select-String -LiteralPath $log -Pattern 'Fatal:|Error:'){throw 'PiP pixel simulation failed'}
 Write-Host "Passed: PiP full-raster pixels, report $report"
} finally {Pop-Location}
