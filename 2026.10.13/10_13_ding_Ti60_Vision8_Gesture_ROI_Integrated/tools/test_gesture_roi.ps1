param([string]$VivadoBin='D:\Xilinx\Vivado\2018.3\bin',[string[]]$Benches=@('tb_gesture_roi_rgb','tb_roi_shared_overlay'))
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$run=Join-Path $project 'sim_roi_integration'
$report=Join-Path $project 'reports/roi_integration'
New-Item -ItemType Directory -Force -Path $run,$report | Out-Null
Get-ChildItem -LiteralPath $project -Filter '*font*.hex' | Copy-Item -Destination $run -Force
$started=Get-Date
$coverage=@{
 tb_gesture_roi_rgb=@('real RGB skin/morphology/CCL pipeline','expanded left/right/top/bottom areas','CCL rejects left/right/top clipping','bottom wrist across ROI accepted','empty scene rejected','SOURCE_TAGGED=1 distinct and duplicate camera IDs')
 tb_roi_shared_overlay=@('SHARED_FONT=1 with active independent HDMI/LCD clocks','all four new guide sides are two pixels','former guide sides disappear','palm sample instruction square fixed','complete right HUD classes 0/1/2/3 match legacy font pixels','pure capture removes guide and HUD')
}
Push-Location $run
try {
 [xml]$proj=Get-Content -LiteralPath (Join-Path $project 'Ti60_Demo.xml')
 $sources=@($proj.project.design_info.design_file | ForEach-Object {$_.name} | Where-Object {$_ -like 'src/vision/*' -or $_ -like 'src/face/*' -or $_ -like 'src/parallel/*' -or $_ -like 'src/gesture/*' -or $_ -like 'rtl/*'} | ForEach-Object {"../$_"})
 $tb=@($Benches | ForEach-Object {"../sim/$_.sv"})
 & (Join-Path $VivadoBin 'xvlog.bat') '--sv' '-i' '../src/parallel' @sources @tb *> '../reports/roi_integration/compile.log'
 if($LASTEXITCODE){throw 'ROI xvlog failed'}
 $results=@()
 foreach($bench in $Benches){
  $benchStarted=Get-Date
  & (Join-Path $VivadoBin 'xelab.bat') $bench '-s' $bench '--relax' *> "../reports/roi_integration/$bench.elab.log"
  if($LASTEXITCODE){throw "ROI xelab failed: $bench"}
  & (Join-Path $VivadoBin 'xsim.bat') $bench '-runall' '-log' "../reports/roi_integration/$bench.log" *> "../reports/roi_integration/$bench.console.log"
  if($LASTEXITCODE){throw "ROI xsim failed: $bench"}
  if(!(Select-String -LiteralPath "../reports/roi_integration/$bench.log" -SimpleMatch 'PASS:')){throw "No PASS: $bench"}
  if(Select-String -LiteralPath "../reports/roi_integration/$bench.log" -Pattern 'Fatal:|Error:'){throw "ROI simulation failure: $bench"}
  $seconds=[math]::Round(((Get-Date)-$benchStarted).TotalSeconds,3)
  $results+=@{bench=$bench;log="reports/roi_integration/$bench.log";status='PASS';started_utc=$benchStarted.ToUniversalTime().ToString('o');completed_utc=(Get-Date).ToUniversalTime().ToString('o');elapsed_seconds=$seconds;coverage=$coverage[$bench]}
  @{started_utc=$started.ToUniversalTime().ToString('o');completed_utc=(Get-Date).ToUniversalTime().ToString('o');project=$project;tool='Vivado 2018.3 XSim';elapsed_seconds=[math]::Round(((Get-Date)-$started).TotalSeconds,3);tests=$results;physical_board_test='not performed'} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $report 'roi_test_results.json') -Encoding UTF8
  Write-Host "Passed: $bench ($seconds seconds)"
 }
} finally {Pop-Location}
