param([string]$VivadoBin='D:\Xilinx\Vivado\2018.3\bin')
$ErrorActionPreference='Stop'
$candidate=$PSScriptRoot
$run=Join-Path $candidate 'simulation'
Push-Location $run
try{
 & (Join-Path $VivadoBin 'xvlog.bat') '--sv' '../banked/rtl/face_grid_regions.v' 'ep1_components.v' 'face_grid_regions_baseline.v' 'ep1_components_baseline.v' 'tb_ramopt_coordinates.sv' *> '../compile.log'
 if($LASTEXITCODE){throw 'Face queue candidate compile failed'}
 & (Join-Path $VivadoBin 'xelab.bat') 'tb_ramopt_coordinates' '-s' 'tb_ramopt_coordinates' '--relax' *> '../elab.log'
 if($LASTEXITCODE){throw 'Face queue candidate elaboration failed'}
 & (Join-Path $VivadoBin 'xsim.bat') 'tb_ramopt_coordinates' '-runall' '-log' '../equivalence.log' *> '../simulation_console.log'
 if($LASTEXITCODE){throw 'Face queue candidate simulation failed'}
 $log=Get-Content -LiteralPath '../equivalence.log' -Raw
 if($log -notmatch 'PASS: coordinate RAM exact equivalence' -or $log -match 'Fatal:|Error:'){throw 'Face queue candidate proof failed'}
 Write-Host ($log -split "`n" | Where-Object {$_ -match 'PASS:'})
}finally{Pop-Location}
