param([ValidateSet('baseline','final')][string]$Phase='baseline')
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$record=Join-Path $project "reports/stage1_20260924/$Phase"
if(Test-Path -LiteralPath $record){throw "Snapshot already exists: $record"}
New-Item -ItemType Directory -Path $record | Out-Null
$files=@(Get-ChildItem -LiteralPath $project -File)+@(Get-ChildItem -LiteralPath "$project/src","$project/ip","$project/tb","$project/tools" -File -Recurse)
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
 $changes | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$record/changed_files.json" -Encoding utf8
 $frozen=@($before.PSObject.Properties | Where-Object {$_.Name -match '^ip/|^src/(cmos_i2c/|axi/|hdmi_ip/|vision/)|^src/(lcd_|Sensor_)|^Ti60_Demo\.(peri\.xml|pt\.sdc)$'})
 $violations=@($frozen | Where-Object {-not $manifest.Contains($_.Name) -or $manifest[$_.Name] -ne $_.Value})
 [pscustomobject]@{checked=$frozen.Count;violations=@($violations.Name)} | ConvertTo-Json | Set-Content -LiteralPath "$record/frozen_boundary_check.json" -Encoding utf8
 if($violations.Count){throw 'Frozen board/vision files changed; inspect report'}
}
[pscustomobject]@{phase=$Phase;path=$record;inputs=$manifest.Count;legacyMatches=@($checks|Where-Object matches).Count;legacyTotal=$checks.Count} | ConvertTo-Json
