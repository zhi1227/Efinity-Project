$ErrorActionPreference='Stop'
Set-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$log="reports/build_$stamp.log"
cmd /d /c "call C:\Efinity\2025.1\bin\setup.bat && call C:\Efinity\2025.1\bin\python3.bat C:\Efinity\2025.1\scripts\efx_run.py Ti60_Demo.xml --flow compile" *> $log
if($LASTEXITCODE -ne 0){Get-Content $log -Tail 60;throw "Efinity compilation failed: $log"}
$timing=Get-Content outflow/Ti60_Demo.timing.rpt -Raw
$summary=[regex]::Match($timing,'(?s)Setup \(Max\) Clock Relationship.*?Clock Relationship Summary \(end\)').Value
$rows=[regex]::Matches($summary,'(?m)^\s+\S+\s+\S+\s+-?\d+\.\d+\s+(-?\d+\.\d+)\s+\([RF]-[RF]\)')
if($rows.Count -lt 26){throw "Missing expected board clock relationships; manually inspect timing ($($rows.Count) rows)"}
foreach($row in $rows){if([double]$row.Groups[1].Value -lt 0){throw "Timing violation: $($row.Value)"}}
$hash=(Get-FileHash outflow/Ti60_Demo.bit -Algorithm SHA256).Hash
@{generated=(Get-Date -Format o);log=$log;bit_sha256=$hash;timing_relationships=$rows.Count;
board_programmed=$false;device='Ti60F225C4';tool='Efinity 2025.1.110.5.9'} |
 ConvertTo-Json | Set-Content reports/build_receipt.json -Encoding utf8
Write-Output "PASS Efinity build, $($rows.Count) nonnegative clock relationships, BIT SHA256=$hash"
