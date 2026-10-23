# ding, 2026-10-15. Isolated RTL simulation; this does not test the board.
param(
 [string]$VivadoBin='D:\Xilinx\Vivado\2018.3\bin',
 [string[]]$Defines=@(),
 [ValidatePattern('^[A-Za-z0-9_-]*$')][string]$RunName=''
)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$run=Join-Path $project 'sim_rgb_balance'
$report=Join-Path $project 'reports/rgb_balance'
if($RunName){$run=Join-Path $run $RunName;$report=Join-Path $report $RunName}
New-Item -ItemType Directory -Force -Path $run,$report | Out-Null
$started=Get-Date
Push-Location $run
try {
 $compilerArgs=@('--sv','-i',(Join-Path $project 'src/parallel'))
 if($Defines.Count){
  # A response file preserves '=' through the legacy Windows batch wrapper.
  $defineOptions=@()
  foreach($definition in $Defines){
   if($definition -notmatch '^[A-Za-z_][A-Za-z0-9_]*(=[0-9]+)?$'){throw "Unsupported test definition: $definition"}
   $defineOptions+="-d $definition"
  }
  $defineFile=Join-Path $run 'defines.rsp'
  $defineOptions | Set-Content -LiteralPath $defineFile -Encoding ASCII
  $compilerArgs+=@('-f',$defineFile)
 }
 $compilerArgs+=@((Join-Path $project 'rtl/camera_rgb_balance.v'),(Join-Path $project 'sim/tb_camera_rgb_balance.sv'))
 & (Join-Path $VivadoBin 'xvlog.bat') @compilerArgs *> (Join-Path $report 'compile.log')
 if($LASTEXITCODE){throw "RGB balance xvlog failed; see $report/compile.log"}
 & (Join-Path $VivadoBin 'xelab.bat') 'tb_camera_rgb_balance' '-s' 'tb_camera_rgb_balance' '--relax' *> (Join-Path $report 'tb_camera_rgb_balance.elab.log')
 if($LASTEXITCODE){throw 'RGB balance xelab failed; see elaboration log'}
 & (Join-Path $VivadoBin 'xsim.bat') 'tb_camera_rgb_balance' '-runall' '-log' (Join-Path $report 'tb_camera_rgb_balance.log') *> (Join-Path $report 'tb_camera_rgb_balance.console.log')
 if($LASTEXITCODE){throw 'RGB balance xsim failed; see simulation log'}
 $log=Join-Path $report 'tb_camera_rgb_balance.log'
 if(!(Select-String -LiteralPath $log -SimpleMatch 'PASS: camera RGB balance')){throw 'RGB balance simulation has no final PASS'}
 if(Select-String -LiteralPath $log -Pattern 'Fatal:|Error:'){throw 'RGB balance simulation reported a failure'}
 @{
  project=$project;author='ding';date='2026-10-15';tool='Vivado XSim 2018.3';status='PASS';
  started_utc=$started.ToUniversalTime().ToString('o');completed_utc=(Get-Date).ToUniversalTime().ToString('o');
  elapsed_seconds=[math]::Round(((Get-Date)-$started).TotalSeconds,3);
  bench='sim/tb_camera_rgb_balance.sv';log=$log;defines=$Defines;run_name=$RunName;
  configuration=@(Select-String -LiteralPath $log -Pattern '^CONFIG:' | ForEach-Object {$_.Line});
  coverage=@('all 65536 RGB565 values: unity and disabled byte identity','exact six-period data and VS latency','1280x720 complete frame and byte statistics','explicit default trial centre/edge and x/y symmetry','current header/defines: signed interpolation, saturation or byte identity','black preservation, blue identity and saturating double gain','odd residual bytes, DE gaps, frame-tail drain and reset','three central knots, protected old outer curve, continuous signed interpolation');
  physical_board_test='not performed';calibration='experimental fixed coefficients; not measured'
 } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $report 'rgb_balance_test_results.json') -Encoding UTF8
 Write-Host "Passed: camera RGB balance (see $report)"
} finally {Pop-Location}
