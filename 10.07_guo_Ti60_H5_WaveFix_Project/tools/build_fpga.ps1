param([string]$Efinity='D:\Efinity')
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
Push-Location $project
try {
 $started=Get-Date
 & (Join-Path $Efinity 'bin/python3.bat') (Join-Path $Efinity 'scripts/efx_run.py') 'Ti60_Demo.xml' '--flow' 'compile' 2>&1 | Tee-Object -FilePath 'reports/efinity_build.log'
 if($LASTEXITCODE){throw 'Efinity process failed; inspect reports/efinity_build.log'}
 # Some Efinity wrappers return 0 despite a stage failure; check each stage.
 foreach($stage in @('map','interface','pnr','pgm')) {
   if(!(Select-String -LiteralPath 'reports/efinity_build.log' -Pattern "^\s*$stage\s*:\s*PASS")) {throw "Efinity stage $stage did not pass"}
 }
 $bit=Get-Item -LiteralPath 'outflow/Ti60_Demo.bit'
 if($bit.LastWriteTime -lt $started){throw 'Bitstream was not regenerated'}
 & (Join-Path $Efinity 'bin/python3.bat') (Join-Path $PSScriptRoot 'verify_build.py')
 if($LASTEXITCODE){throw 'Resource/timing/source validation failed'}
 Write-Host 'New bitstream generated. This script does not program hardware.'
} finally {Pop-Location}
