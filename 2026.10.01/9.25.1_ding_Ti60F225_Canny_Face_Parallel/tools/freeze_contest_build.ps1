param([string]$ReportDir='reports/contest_20260925', [string]$SimDir='reports/contest_20260925/final_sim')
$ErrorActionPreference='Stop'
$taskRoot=Split-Path $PSScriptRoot -Parent
$taskReport=Join-Path $taskRoot $ReportDir
$taskFinal=Join-Path $taskReport 'final'
if(Test-Path -LiteralPath $taskFinal){throw 'Final evidence exists; use a fresh report, never overwrite.'}
$tests=@('tb_parallel','tb_controls','tb_720p','tb_face_grid_regions','canny_threshold_ports_tb','hysteresis_local_tb','rgb565_to_ycbcr_skin_tb','tb_stage1_display','tb_freeze','tb_shape','tb_contest_video','tb_filters')
foreach($name in $tests){
 $log=Get-Content -LiteralPath (Join-Path $taskRoot "$SimDir/$name.log") -Raw
 if($log -notmatch 'PASS' -or $log -notmatch '\$finish' -or $log -match 'Fatal:|FAIL:|FAILED|ERROR:'){throw "Simulation did not pass: $name"}
}
$timing=Get-Content -LiteralPath "$taskRoot/outflow/Ti60_Demo.timing.rpt" -Raw
$relationships=($timing -split 'Clock Relationship Summary \(begin\)')[1] -split 'Clock Relationship Summary \(end\)' | Select-Object -First 1
$slacks=[regex]::Matches($relationships,'(?m)^\s+(\w+)\s+(\w+)\s+(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+\(')
if($slacks.Count -ne 26){throw "Unexpected relationship count $($slacks.Count)"}
foreach($s in $slacks){if([double]$s.Groups[4].Value -lt 0){throw 'Timing violation'}}
New-Item -ItemType Directory -Path $taskFinal | Out-Null
foreach($file in @('Ti60_Demo.bit','Ti60_Demo.hex','Ti60_Demo.bit.bin','Ti60_Demo.hex.bin','Ti60_Demo.map.rpt','Ti60_Demo.route.rpt','Ti60_Demo.timing.rpt','Ti60_Demo.pt.rpt')){
 Copy-Item -LiteralPath "$taskRoot/outflow/$file" -Destination $taskFinal
}
$manifest=[ordered]@{}
$files=@(Get-Item -LiteralPath "$taskRoot/example_top.v","$taskRoot/Ti60_Demo.xml","$taskRoot/Ti60_Demo.peri.xml","$taskRoot/Ti60_Demo.pt.sdc")
foreach($folder in @('src','ip','tb','tools')){
 $files+=Get-ChildItem -LiteralPath "$taskRoot/$folder" -Recurse -File | Where-Object {$_.Extension -in '.v','.sv','.vh','.vhd','.sdc','.mem','.hex','.json','.xml','.ps1','.py','.tcl'}
}
$files+=Get-ChildItem -LiteralPath $taskFinal -File
foreach($file in ($files | Sort-Object FullName -Unique)){
 $rel=[IO.Path]::GetRelativePath($taskRoot,$file.FullName).Replace('\','/')
 $manifest[$rel]=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$taskFinal/build_manifest.json" -Encoding utf8
$result=[ordered]@{status='PASS'; created=(Get-Date -Format o); tests=$tests; manifest_files=$manifest.Count;
 setup_slack_min_ns=($slacks[0..12] | ForEach-Object {[double]$_.Groups[4].Value} | Measure-Object -Minimum).Minimum;
 hold_slack_min_ns=($slacks[13..25] | ForEach-Object {[double]$_.Groups[4].Value} | Measure-Object -Minimum).Minimum;
 bit_sha256=(Get-FileHash -LiteralPath "$taskFinal/Ti60_Demo.bit" -Algorithm SHA256).Hash.ToLowerInvariant();
 hardware_status='NOT_PROGRAMMED_USB_NOT_ENUMERATED'; flash_status='UNCHANGED'; real_video_acceptance='PENDING'}
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$taskFinal/verification.json" -Encoding utf8
$result | ConvertTo-Json -Depth 5
