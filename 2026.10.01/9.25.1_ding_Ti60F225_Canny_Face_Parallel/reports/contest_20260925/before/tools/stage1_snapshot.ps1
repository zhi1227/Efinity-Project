param([ValidateSet('baseline','final')][string]$Phase='baseline')
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$record=Join-Path $project "reports/stage1_20260924/$Phase"
if(Test-Path -LiteralPath $record){throw "Snapshot already exists: $record"}
New-Item -ItemType Directory -Path $record | Out-Null
$files=@(Get-ChildItem -LiteralPath $project -File)+@(Get-ChildItem -LiteralPath "$project/src","$project/ip","$project/tb","$project/tools" -File -Recurse | Where-Object {$_.FullName -notmatch '[\\/]__pycache__[\\/]'})
if(Test-Path -LiteralPath "$project/docs/stage1_dataset"){$files+=@(Get-ChildItem -LiteralPath "$project/docs/stage1_dataset" -File -Recurse)}
$manifest=[ordered]@{}
foreach($file in $files){
 $rel=$file.FullName.Substring($project.Length+1).Replace('\','/')
 $manifest[$rel]=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLower()
 if($Phase -eq 'baseline' -and -not $rel.StartsWith('ip/')){
  $dest=Join-Path "$record/files" $rel
  New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
  Copy-Item -LiteralPath $file.FullName -Destination $dest
 }
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$record/input_sha256.json" -Encoding utf8
$old=Get-Content -LiteralPath "$project/reports/build_manifest.json" -Raw | ConvertFrom-Json
$checks=@(foreach($entry in $old.PSObject.Properties){
 $target=Join-Path $project $entry.Name
 $actual=if(Test-Path -LiteralPath $target){(Get-FileHash -LiteralPath $target).Hash.ToLower()}else{'MISSING'}
 [pscustomobject]@{path=$entry.Name;recorded=$entry.Value;actual=$actual;matches=($entry.Value -eq $actual)}
})
$checks | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$record/legacy_manifest_check.json" -Encoding utf8
if($Phase -eq 'baseline'){
 New-Item -ItemType Directory -Path "$record/artifacts","$record/legacy_reports","$record/legacy_sim_logs" | Out-Null
 Get-ChildItem -LiteralPath "$project/outflow" -File | Where-Object {$_.Name -match '\.(bit|hex)(\.bin)?$|\.(rpt|csv|log)$'} | Copy-Item -Destination "$record/artifacts"
 Get-ChildItem -LiteralPath "$project/reports" -File | Copy-Item -Destination "$record/legacy_reports"
 Get-ChildItem -LiteralPath "$project/sim_parallel" -File -Filter '*.log' | Copy-Item -Destination "$record/legacy_sim_logs"
}else{
 $before=Get-Content -LiteralPath "$project/reports/stage1_20260924/baseline/input_sha256.json" -Raw | ConvertFrom-Json
 $changes=@(foreach($key in $manifest.Keys){
  $oldHash=$before.PSObject.Properties[$key]
  if($null -eq $oldHash){[pscustomobject]@{path=$key;status='added'}}
  elseif($oldHash.Value -ne $manifest[$key]){[pscustomobject]@{path=$key;status='modified'}}
 })
 $changes+=@(foreach($entry in $before.PSObject.Properties){if(-not $manifest.Contains($entry.Name)){[pscustomobject]@{path=$entry.Name;status='removed'}}})
 $changes | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$record/changed_files.json" -Encoding utf8
 $frozen=@($before.PSObject.Properties | Where-Object {$_.Name -match '^ip/|^src/(cmos_i2c/|axi/|hdmi_ip/|vision/)|^src/(lcd_|Sensor_)|^Ti60_Demo\.(peri\.xml|pt\.sdc)$'})
 $violations=@($frozen | Where-Object {-not $manifest.Contains($_.Name) -or $manifest[$_.Name] -ne $_.Value})
 [pscustomobject]@{checked=$frozen.Count;violations=@($violations|ForEach-Object Name)} | ConvertTo-Json | Set-Content -LiteralPath "$record/frozen_boundary_check.json" -Encoding utf8
 if($violations.Count){throw 'Frozen board/vision files changed; inspect report'}
 $route=Get-Content -LiteralPath "$project/outflow/Ti60_Demo.route.rpt" -Raw
 $timing=Get-Content -LiteralPath "$project/outflow/Ti60_Demo.timing.rpt" -Raw
 $setupText=[regex]::Match($timing,'(?s)Setup \(Max\) Clock Relationship(.*?)Hold \(Min\) Clock Relationship').Groups[1].Value
 $holdText=[regex]::Match($timing,'(?s)Hold \(Min\) Clock Relationship(.*?)NOTE:').Groups[1].Value
 function Parse-ClockRows([string]$block){
  foreach($m in [regex]::Matches($block,'(?m)^\s+(\w+)\s+(\w+)\s+(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+\(([RF]-[RF])\)')){
   [pscustomobject]@{launch=$m.Groups[1].Value;capture=$m.Groups[2].Value;constraint_ns=[double]$m.Groups[3].Value;slack_ns=[double]$m.Groups[4].Value;edge=$m.Groups[5].Value}
  }
 }
 $setup=@(Parse-ClockRows $setupText);$hold=@(Parse-ClockRows $holdText)
 if(-not $setup.Count -or -not $hold.Count){throw 'Cannot parse timing tables'}
 $setupMin=($setup.slack_ns|Measure-Object -Minimum).Minimum
 $holdMin=($hold.slack_ns|Measure-Object -Minimum).Minimum
 if($setupMin -lt 0 -or $holdMin -lt 0){throw 'Timing violation'}
 $xlr=[regex]::Match($route,'XLRs: (\d+) / (\d+)')
 $ram=[regex]::Match($route,'Memory Blocks: (\d+) / (\d+)')
 $dsp=[regex]::Match($route,'DSP Blocks: (\d+) / (\d+)')
 if(-not $xlr.Success -or -not $ram.Success -or -not $dsp.Success){throw 'Cannot parse resources'}
 $tests=@('tb_parallel','tb_controls','tb_720p','tb_face_grid_regions','canny_threshold_ports_tb','hysteresis_local_tb','rgb565_to_ycbcr_skin_tb','tb_stage1_display')
 $results=@(foreach($test in $tests){
  $log="reports/stage1_20260924/sim_run03/$test.log"
  $text=Get-Content -LiteralPath (Join-Path $project $log) -Raw
  $ok=$text -match 'PASS' -and $text -notmatch 'Fatal:|FAIL:|FAILED|ERROR:'
  if(-not $ok){throw "Test failed: $test"}
  [pscustomobject]@{name=$test;pass=$ok;log=$log}
 })
 $summary=[ordered]@{date='2026-09-24';project=$project;stage='1';board_downloaded=$false;flash_written=$false;
  xlr_used=[int]$xlr.Groups[1].Value;xlr_capacity=[int]$xlr.Groups[2].Value;
  memory_used=[int]$ram.Groups[1].Value;memory_capacity=[int]$ram.Groups[2].Value;
  dsp_used=[int]$dsp.Groups[1].Value;dsp_capacity=[int]$dsp.Groups[2].Value;
  worst_setup_ns=$setupMin;worst_hold_ns=$holdMin;setup=$setup;hold=$hold;tests=$results;
  frozen_files=$frozen.Count;frozen_changed=0;T02_real_samples='PENDING';default_mode=3;default_low=40;default_high=80}
 $summary|ConvertTo-Json -Depth 8|Set-Content -LiteralPath "$record/final_results.json" -Encoding utf8
 [xml]$xml=Get-Content -LiteralPath "$project/Ti60_Demo.xml" -Raw
 $active=@($xml.SelectNodes("//*[local-name()='design_file']")|ForEach-Object {$_.GetAttribute('name')})
 $active+=@('src/parallel/vision_config.vh','Ti60_Demo.xml','Ti60_Demo.peri.xml','Ti60_Demo.pt.sdc','outflow/Ti60_Demo.bit','outflow/Ti60_Demo.hex','outflow/Ti60_Demo.bit.bin','outflow/Ti60_Demo.hex.bin')
 $build=[ordered]@{}
 foreach($rel in $active){$build[$rel]=(Get-FileHash -LiteralPath (Join-Path $project $rel)).Hash.ToLower()}
 $build|ConvertTo-Json -Depth 5|Set-Content -LiteralPath "$record/build_manifest.json" -Encoding utf8
 New-Item -ItemType Directory -Path "$record/artifacts" | Out-Null
 Get-ChildItem -LiteralPath "$project/outflow" -File | Where-Object {$_.Name -match '\.(bit|hex)(\.bin)?$|\.(rpt|csv|log)$'} | Copy-Item -Destination "$record/artifacts"
}
[pscustomobject]@{phase=$Phase;path=$record;inputs=$manifest.Count;legacyMatches=@($checks|Where-Object matches).Count;legacyTotal=$checks.Count} | ConvertTo-Json
