param([string]$VivadoBin='D:\Xilinx\Vivado\2018.3\bin')
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$run=Join-Path $project 'sim_official_isp'
$report=Join-Path $project 'reports/official_isp'
New-Item -ItemType Directory -Force -Path $run,$report | Out-Null
$started=(Get-Date).ToUniversalTime().ToString('o')
# Keep the licensed official source intact; rename only a simulation copy.
$reference=Get-Content -LiteralPath (Join-Path $project 'reference/official_camera_20251009/I2C_OV5640_1280720_Config.v') -Raw
$reference=$reference.Replace('module'+[char]9+'I2C_OV5640_1280720_Config','module official_OV5640_Config')
if($reference -notmatch 'module official_OV5640_Config'){throw 'Cannot rename official reference module'}
$reference | Set-Content -LiteralPath (Join-Path $run 'official_reference.v') -Encoding UTF8
Push-Location $run
try {
 $sources=@('official_reference.v','../src/cmos_i2c/I2C_OV5640_1280720_Config.v',
  '../src/cmos_i2c/i2c_timing_ctrl_16bit.v','../sim/tb_camera_official_isp.sv','../sim/tb_i2c6.sv')
 & (Join-Path $VivadoBin 'xvlog.bat') '--sv' @sources *> (Join-Path $report 'compile.log')
 if($LASTEXITCODE){throw 'Official ISP compilation failed'}
 $tests=@()
 foreach($bench in @('tb_camera_official_isp','tb_i2c6')){
  & (Join-Path $VivadoBin 'xelab.bat') $bench '-s' $bench '--relax' *> (Join-Path $report "$bench.elab.log")
  if($LASTEXITCODE){throw "Elaboration failed: $bench"}
  $log=Join-Path $report "$bench.log"
  & (Join-Path $VivadoBin 'xsim.bat') $bench '-runall' '-log' $log *> (Join-Path $report "$bench.console.log")
  if($LASTEXITCODE){throw "Simulation failed: $bench"}
  if(!(Select-String -LiteralPath $log -SimpleMatch 'PASS:') -or (Select-String -LiteralPath $log -Pattern 'Fatal:|Error:|^ERROR:')){throw "Missing PASS or failed assertions: $bench"}
  $tests+=@{bench=$bench;status='PASS';log="reports/official_isp/$bench.log";sha256=(Get-FileHash -LiteralPath $log -Algorithm SHA256).Hash.ToLowerInvariant()}
  Write-Host "Passed: $bench"
 }
 @{started_utc=$started;completed_utc=(Get-Date).ToUniversalTime().ToString('o');tests=$tests;physical_board_test='not performed'} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $report 'sensor_tests.json') -Encoding UTF8
} finally {Pop-Location}
