param([string]$Efinity='C:\Efinity\2025.1')
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$savedBuildPythonHome=$env:PYTHONHOME
Push-Location $project
try {
 $env:PYTHONHOME=Join-Path $Efinity 'python311'
 & (Join-Path $Efinity 'python311/bin/python.exe') (Join-Path $PSScriptRoot 'verify_build.py') '--snapshot'
 if($LASTEXITCODE){throw 'Build input snapshot failed'}
 $started=Get-Date
 & (Join-Path $Efinity 'bin/python3.bat') (Join-Path $Efinity 'scripts/efx_run.py') 'Ti60_Demo.xml' '--flow' 'compile' 2>&1 | Tee-Object -FilePath 'reports/efinity_build.log'
 if($LASTEXITCODE){throw 'Efinity process failed; inspect reports/efinity_build.log'}
 # Some Efinity wrappers return 0 despite a stage failure; check each stage.
 foreach($stage in @('map','interface','pnr','pgm')) {
   if(!(Select-String -LiteralPath 'reports/efinity_build.log' -Pattern "^\s*$stage\s*:\s*PASS")) {throw "Efinity stage $stage did not pass"}
 }
 $bit=Get-Item -LiteralPath 'outflow/Ti60_Demo.bit'
 if($bit.LastWriteTime -lt $started){throw 'Bitstream was not regenerated'}
 & (Join-Path $Efinity 'python311/bin/python.exe') (Join-Path $PSScriptRoot 'verify_build.py')
 if($LASTEXITCODE){throw 'Resource/timing/source validation failed'}
 Write-Host 'New bitstream generated. This script does not program hardware.'
} finally {$env:PYTHONHOME=$savedBuildPythonHome;Pop-Location}
