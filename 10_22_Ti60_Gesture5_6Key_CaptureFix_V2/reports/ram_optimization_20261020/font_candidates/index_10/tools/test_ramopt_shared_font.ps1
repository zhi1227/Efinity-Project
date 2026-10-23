param([string]$VivadoBin='D:\Xilinx\Vivado\2018.3\bin')
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$run=Join-Path $project 'sim_ramopt_font'
$report=Join-Path $project 'reports/ram_optimization_20261020/font'
New-Item -ItemType Directory -Force -Path $report | Out-Null
Get-ChildItem -LiteralPath $project -Filter 'shared_font*.hex' -File | Copy-Item -Destination $run -Force
Push-Location $run
try {
 & (Join-Path $VivadoBin 'xvlog.bat') '--sv' '../rtl/shared_glyph_rom.v' 'shared_glyph_rom_reference.v' 'tb_ramopt_shared_font.sv' *> (Join-Path $report 'compile.log')
 if($LASTEXITCODE){throw 'shared font compile failed'}
 & (Join-Path $VivadoBin 'xelab.bat') 'tb_ramopt_shared_font' '-s' 'tb_ramopt_shared_font' '--relax' *> (Join-Path $report 'elab.log')
 if($LASTEXITCODE){throw 'shared font elaboration failed'}
 & (Join-Path $VivadoBin 'xsim.bat') 'tb_ramopt_shared_font' '-runall' '-log' (Join-Path $report 'tb_ramopt_shared_font.log') *> (Join-Path $report 'console.log')
 if($LASTEXITCODE){throw 'shared font simulation failed'}
 $log=Get-Content -LiteralPath (Join-Path $report 'tb_ramopt_shared_font.log') -Raw
 if($log -notmatch 'PASS: compressed shared font' -or $log -match 'Fatal:|Error:'){throw 'shared font equivalence failed'}
 Write-Host ($log -split "`n" | Where-Object {$_ -match 'PASS:'})
} finally {Pop-Location}
