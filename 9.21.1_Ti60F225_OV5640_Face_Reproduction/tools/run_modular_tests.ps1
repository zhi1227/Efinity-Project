param([string]$VivadoBin='D:/Xilinx/Vivado/2018.3/bin',[switch]$Full720p)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
$runDir=Join-Path $projectRoot ('sim_modular/run_'+(Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Force $runDir | Out-Null
Push-Location $projectRoot
try {
 New-Item -ItemType Directory -Force sim_modular | Out-Null
 $sources=@(Get-ChildItem src/vision/*.v | ForEach-Object FullName)+@(
 'src/face/rgb565_to_ycbcr_skin.v','src/face/face_grid_regions.v',
 'src/face/face_candidate_pipeline.v','src/face/face_box_stabilizer.v',
 'tb/vision/tb_modular_video.v','tb/vision/tb_face_overlay.v',
 'tb/face/tb_face_grid_regions.v','tb/face/tb_face_stabilizer.v',
 'tb/vision/tb_video_720p.v')
 $sources=@($sources | ForEach-Object {(Resolve-Path $_).Path})
 Set-Location $runDir
 & "$VivadoBin/xvlog.bat" @sources
 if($LASTEXITCODE -ne 0){throw 'HDL compile failed'}
 $tests=@('tb_modular_video','tb_face_grid_regions','tb_face_overlay','tb_face_stabilizer')
 if($Full720p){$tests+='tb_video_720p'}
 foreach($test in $tests){
   & "$VivadoBin/xelab.bat" $test -s $test -mt 2
   if($LASTEXITCODE -ne 0){throw "Elaboration failed: $test"}
   $output=& "$VivadoBin/xsim.bat" $test -runall 2>&1
   $output | Tee-Object -FilePath (Join-Path $projectRoot "sim_modular/$test.log")
   $body=$output -join [Environment]::NewLine
   if($LASTEXITCODE -ne 0 -or $body -notmatch 'PASS ' -or $body -match 'Fatal:|ERROR:'){
     throw "Simulation failed: $test"
   }
 }
 Write-Host 'ALL REQUESTED TESTS PASSED'
} finally {Pop-Location}
