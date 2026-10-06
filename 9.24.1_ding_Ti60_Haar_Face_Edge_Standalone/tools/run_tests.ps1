param([string]$VivadoBin='D:/Xilinx/Vivado/2018.3/bin')
$ErrorActionPreference='Stop'
$p=Split-Path $PSScriptRoot -Parent
Push-Location $p
try {
 $src=@('src/haar/haar_engine.v','src/haar/gray_thumbnail.v','src/haar/haar_box_tracker.v','src/haar/haar_face_video.v','src/vision/rgb565_to_gray.v','src/vision/rgb565_to_rgb888.v','src/vision/line_buffer_3x3.v','src/vision/sobel3x3.v','src/parallel/video_delay.v','src/parallel/uart_params.v','tb/tb_haar.v','tb/tb_haar_video.v','tb/tb_haar_integration.v','tb/tb_haar_selftest.v','tb/tb_haar_tracker.v','tb/tb_gray_thumbnail.v','tb/tb_haar_near.v')
 & "$VivadoBin/xvlog.bat" @src *> sim/compile_all.log
 if($LASTEXITCODE -ne 0){throw 'xvlog failed; see sim/compile_all.log'}
 foreach($t in @('tb_haar','tb_haar_video','tb_haar_integration','tb_haar_selftest','tb_haar_tracker','tb_gray_thumbnail','tb_haar_near')) {
  & "$VivadoBin/xelab.bat" $t -s $t -mt 2 *> "sim/$t.elab.log"
  if($LASTEXITCODE -ne 0){throw "xelab failed: $t"}
  & "$VivadoBin/xsim.bat" $t -runall *> "sim/$t.log"
  $s=Get-Content -LiteralPath "sim/$t.log" -Raw
  if($LASTEXITCODE -ne 0 -or $s -notmatch 'PASS' -or $s -notmatch '\$finish called' -or $s -match 'Fatal:|FAIL|ERROR:'){throw "test failed: $t"}
  Write-Output "$t PASS"
 }
}finally{Pop-Location}

