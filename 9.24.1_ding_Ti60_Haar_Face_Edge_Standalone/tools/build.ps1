$ErrorActionPreference='Stop'
$p=Split-Path $PSScriptRoot -Parent
Push-Location $p
try {
 & 'C:/Efinity/2025.1/bin/python3.bat' 'C:/Efinity/2025.1/scripts/efx_run.py' Ti60_Demo.xml --flow compile *> reports/build.log
 $log=Get-Content -LiteralPath reports/build.log -Raw
 if($LASTEXITCODE -ne 0 -or $log -match 'FAIL|ERROR' -or $log -notmatch 'pnr\s*:\s*PASS' -or $log -notmatch 'pgm\s*:\s*PASS'){throw 'Build failed; inspect reports/build.log and outflow'}
 Write-Output 'Build PASS. Inspect outflow/Ti60_Demo.timing.rpt before JTAG download.'
}finally{Pop-Location}
