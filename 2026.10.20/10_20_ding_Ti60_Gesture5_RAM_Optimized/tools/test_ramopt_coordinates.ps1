param([string]$VivadoBin='D:\Xilinx\Vivado\2018.3\bin')
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$run=Join-Path $project 'sim_ramopt_coordinates'
$report=Join-Path $project 'reports/ramopt_coordinates'
New-Item -ItemType Directory -Force -Path $report | Out-Null
$refs=@(
 @{path='src/parallel/face_grid_regions.v';file='face_grid_regions.v';names=@('face_grid_regions')},
 @{path='src/gesture/ep1_components.v';file='ep1_components.v';names=@('ep1_classify','ep1_gesture')}
)
$hashes=@{}
$optimizedHashes=@{}
$startedUtc=(Get-Date).ToUniversalTime().ToString('o')
foreach($ref in $refs){
 $inputFile=Join-Path $project ('reference/ram_optimization_20261020/'+$ref.file)
 $data=[System.IO.File]::ReadAllText($inputFile)
 $hashes[$ref.path]=(Get-FileHash -LiteralPath $inputFile -Algorithm SHA256).Hash.ToLowerInvariant()
 $optimizedHashes[$ref.path]=(Get-FileHash -LiteralPath (Join-Path $project $ref.path) -Algorithm SHA256).Hash.ToLowerInvariant()
 foreach($moduleName in $ref.names){$data=[regex]::Replace($data,'\b'+$moduleName+'\b',$moduleName+'_baseline')}
 [System.IO.File]::WriteAllText((Join-Path $run ($ref.file -replace '\.v$','_baseline.v')),$data,[System.Text.UTF8Encoding]::new($false))
}
Push-Location $run
try{
 & (Join-Path $VivadoBin 'xvlog.bat') '--sv' '../src/parallel/face_grid_regions.v' '../src/gesture/ep1_components.v' 'face_grid_regions_baseline.v' 'ep1_components_baseline.v' 'tb_ramopt_coordinates.sv' *> '../reports/ramopt_coordinates/compile.log'
 if($LASTEXITCODE){throw 'Coordinate equivalence compile failed'}
 & (Join-Path $VivadoBin 'xelab.bat') 'tb_ramopt_coordinates' '-s' 'tb_ramopt_coordinates' '--relax' *> '../reports/ramopt_coordinates/elab.log'
 if($LASTEXITCODE){throw 'Coordinate equivalence elaboration failed'}
 & (Join-Path $VivadoBin 'xsim.bat') 'tb_ramopt_coordinates' '-runall' '-log' '../reports/ramopt_coordinates/equivalence.log' *> '../reports/ramopt_coordinates/console.log'
 if($LASTEXITCODE){throw 'Coordinate equivalence simulation failed'}
 $log=Join-Path $report 'equivalence.log'
 if(!(Select-String -LiteralPath $log -SimpleMatch 'PASS: coordinate RAM exact equivalence')){throw 'Coordinate equivalence did not complete'}
 if(Select-String -LiteralPath $log -Pattern 'Fatal:|Error:'){throw 'Coordinate equivalence reported errors'}
 foreach($path in $optimizedHashes.Keys){if((Get-FileHash -LiteralPath (Join-Path $project $path) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $optimizedHashes[$path]){throw "Source changed during coordinate proof: $path"}}
 @{result='PASS';face_grids=@('160x90','48x32');ccl_modes=@('10bit LABEL_CAP1024','10bit LABEL_CAP8','11bit LABEL_CAP1024');baseline_sha256=$hashes;optimized_sha256=$optimizedHashes;bench='sim_ramopt_coordinates/tb_ramopt_coordinates.sv';bench_sha256=(Get-FileHash -LiteralPath (Join-Path $run 'tb_ramopt_coordinates.sv') -Algorithm SHA256).Hash.ToLowerInvariant();log='reports/ramopt_coordinates/equivalence.log';log_sha256=(Get-FileHash -LiteralPath $log -Algorithm SHA256).Hash.ToLowerInvariant();started_at=$startedUtc;ended_at=(Get-Date).ToUniversalTime().ToString('o');hardware_validation='not performed'} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $report 'results.json') -Encoding UTF8
 Write-Host 'PASS: Coordinate RAM cycle-exact equivalence'
}finally{Pop-Location}
