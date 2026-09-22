$ErrorActionPreference='Stop'
$p=Split-Path $PSScriptRoot -Parent
$bin='D:/Xilinx/Vivado/2018.3/bin'
New-Item -ItemType Directory -Force "$p/sim_parallel" | Out-Null
$sources=@(Get-ChildItem "$p/src/vision/*.v"|ForEach-Object FullName)+@(Get-ChildItem "$p/src/parallel/*.v"|ForEach-Object FullName)+@("$p/src/face/rgb565_to_ycbcr_skin.v")+@(Get-ChildItem "$p/tb/parallel/*.v"|ForEach-Object FullName)+@("$p/tb/vision/canny_threshold_ports_tb.v","$p/tb/vision/hysteresis_local_tb.v","$p/tb/face/rgb565_to_ycbcr_skin_tb.v")
Push-Location "$p/sim_parallel"
try {
& "$bin/xvlog.bat" @sources *> compile.log
if($LASTEXITCODE -ne 0){Get-Content compile.log -Tail 30;throw 'compile failed'}
foreach($t in @('tb_parallel','tb_controls','tb_720p','tb_face_grid_regions','canny_threshold_ports_tb','hysteresis_local_tb','rgb565_to_ycbcr_skin_tb')) {
& "$bin/xelab.bat" $t -s $t -mt 2 *> "$t.elab.log"
if($LASTEXITCODE -ne 0){Get-Content "$t.elab.log" -Tail 30;throw "elab $t"}
& "$bin/xsim.bat" $t -runall *> "$t.log"
$txt=Get-Content "$t.log" -Raw
Write-Output $txt
if($LASTEXITCODE -ne 0 -or $txt -notmatch 'PASS' -or $txt -match 'Fatal:|FAIL:|FAILED|ERROR:'){throw "test $t failed"}
}
} finally {Pop-Location}
