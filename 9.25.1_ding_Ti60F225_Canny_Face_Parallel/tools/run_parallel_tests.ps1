param([string]$OutputDir='sim_parallel',[string[]]$Tests=@('tb_parallel','tb_controls','tb_720p','tb_face_grid_regions','canny_threshold_ports_tb','hysteresis_local_tb','rgb565_to_ycbcr_skin_tb','tb_stage1_display','tb_freeze','tb_shape','tb_contest_video','tb_filters'))
$ErrorActionPreference='Stop'
$p=Split-Path $PSScriptRoot -Parent
$bin='D:/Xilinx/Vivado/2018.3/bin'
$sim=if([IO.Path]::IsPathRooted($OutputDir)){$OutputDir}else{Join-Path $p $OutputDir}
New-Item -ItemType Directory -Force $sim | Out-Null
$sources=@(Get-ChildItem "$p/src/vision/*.v"|ForEach-Object FullName)+@(Get-ChildItem "$p/src/parallel/*.v"|ForEach-Object FullName)+@("$p/src/axi/frame_buffer_select.v","$p/src/face/rgb565_to_ycbcr_skin.v")+@(Get-ChildItem "$p/tb/parallel/*.v"|ForEach-Object FullName)+@("$p/tb/vision/canny_threshold_ports_tb.v","$p/tb/vision/hysteresis_local_tb.v","$p/tb/face/rgb565_to_ycbcr_skin_tb.v")
Push-Location $sim
try {
& "$bin/xvlog.bat" -i "$p/src/parallel" @sources *> compile.log
if($LASTEXITCODE -ne 0){Get-Content compile.log -Tail 30;throw 'compile failed'}
foreach($t in $Tests) {
& "$bin/xelab.bat" $t -s $t -mt 2 -debug typical *> "$t.elab.log"
if($LASTEXITCODE -ne 0){Get-Content "$t.elab.log" -Tail 30;throw "elab $t"}
& "$bin/xsim.bat" $t -runall *> "$t.log"
$txt=Get-Content "$t.log" -Raw
Write-Output $txt
if($LASTEXITCODE -ne 0 -or $txt -notmatch 'PASS' -or $txt -match 'Fatal:|FAIL:|FAILED|ERROR:'){throw "test $t failed"}
}
} finally {Pop-Location}
