param(
 [string]$VivadoBin='D:\Xilinx\Vivado\2018.3\bin',
 [string]$BaselineProject=''
)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
if(!$BaselineProject){$BaselineProject=Join-Path (Split-Path -Parent $project) '10_20_Gesture5_RAM_Baseline'}
$run=Join-Path $project 'sim_ramopt'
$report=Join-Path $project 'reports/ramopt_buffers'
New-Item -ItemType Directory -Force -Path $report | Out-Null
$refs=@(
 @{path='src/vision/line_buffer_3x3.v';out='line_buffer_3x3_baseline.v';names=@('line_buffer_3x3')},
 @{path='src/gesture/ep1_skin.v';out='ep1_skin_baseline.v';names=@('ep1_skin','ep1_window7','ep1_disk')},
 @{path='src/parallel/video_delay.v';out='video_delay_baseline.v';names=@('video_delay')}
)
$hashes=@{}
$optimizedHashes=@{}
$startedUtc=(Get-Date).ToUniversalTime().ToString('o')
foreach($ref in $refs){
 $inputFile=Join-Path $BaselineProject $ref.path
 $data=[System.IO.File]::ReadAllText($inputFile)
 $hashes[$ref.path]=(Get-FileHash -LiteralPath $inputFile -Algorithm SHA256).Hash.ToLowerInvariant()
 $optimizedHashes[$ref.path]=(Get-FileHash -LiteralPath (Join-Path $project $ref.path) -Algorithm SHA256).Hash.ToLowerInvariant()
 foreach($moduleName in $ref.names){$data=[regex]::Replace($data,'\bmodule\s+'+$moduleName+'\b','module '+$moduleName+'_baseline')}
 [System.IO.File]::WriteAllText((Join-Path $run $ref.out),$data,[System.Text.UTF8Encoding]::new($false))
}
Push-Location $run
try{
 $sources=@('../src/vision/line_buffer_3x3.v','../src/gesture/ep1_skin.v','../src/parallel/video_delay.v','line_buffer_3x3_baseline.v','ep1_skin_baseline.v','video_delay_baseline.v','tb_ramopt_buffers.sv')
 & (Join-Path $VivadoBin 'xvlog.bat') '--sv' @sources *> '../reports/ramopt_buffers/compile.log'
 if($LASTEXITCODE){throw 'RAM buffer equivalence compile failed'}
 & (Join-Path $VivadoBin 'xelab.bat') 'tb_ramopt_buffers' '-s' 'tb_ramopt_buffers' '--relax' *> '../reports/ramopt_buffers/elab.log'
 if($LASTEXITCODE){throw 'RAM buffer equivalence elaboration failed'}
 & (Join-Path $VivadoBin 'xsim.bat') 'tb_ramopt_buffers' '-runall' '-log' '../reports/ramopt_buffers/equivalence.log' *> '../reports/ramopt_buffers/console.log'
 if($LASTEXITCODE){throw 'RAM buffer equivalence simulation failed'}
 $log=Join-Path $report 'equivalence.log'
 if(!(Select-String -LiteralPath $log -SimpleMatch 'PASS: RAM buffers exact equivalence')){throw 'RAM buffer equivalence did not complete'}
 if(Select-String -LiteralPath $log -Pattern 'Fatal:|Error:'){throw 'RAM buffer equivalence reported errors'}
 foreach($path in $optimizedHashes.Keys){if((Get-FileHash -LiteralPath (Join-Path $project $path) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $optimizedHashes[$path]){throw "Source changed during buffer proof: $path"}}
 @{result='PASS';clocks=90000;line_configurations=9;window7_widths=3;delay_configurations=14;baseline_project=$BaselineProject;baseline_sha256=$hashes;optimized_sha256=$optimizedHashes;bench='sim_ramopt/tb_ramopt_buffers.sv';bench_sha256=(Get-FileHash -LiteralPath (Join-Path $run 'tb_ramopt_buffers.sv') -Algorithm SHA256).Hash.ToLowerInvariant();log='reports/ramopt_buffers/equivalence.log';log_sha256=(Get-FileHash -LiteralPath $log -Algorithm SHA256).Hash.ToLowerInvariant();started_at=$startedUtc;ended_at=(Get-Date).ToUniversalTime().ToString('o');hardware_validation='not performed'} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $report 'results.json') -Encoding UTF8
 Write-Host 'PASS: RAM buffer cycle-exact equivalence'
}finally{Pop-Location}
