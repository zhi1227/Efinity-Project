param([string]$VivadoBin='D:\Xilinx\Vivado\2018.3\bin')
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$run=Join-Path $project 'sim_ramopt_font'
$report=Join-Path $project 'reports/ram_optimization_20261020/font'
New-Item -ItemType Directory -Force -Path $report | Out-Null
$resultFile=Join-Path $report 'results.json'
if(Test-Path -LiteralPath $resultFile){Remove-Item -LiteralPath $resultFile}
$started=[DateTime]::UtcNow.ToString('o')
function File-Sha([string]$relative) {
 (Get-FileHash -LiteralPath (Join-Path $project $relative) -Algorithm SHA256).Hash.ToLowerInvariant()
}
# The baseline references are fixed fixtures. A changed font must fail instead
# of silently replacing the old picture/ROM and validating against itself.
$manifestPath='sim_ramopt_font/font_reference_manifest.json'
$manifest=Get-Content -LiteralPath (Join-Path $project $manifestPath) -Raw | ConvertFrom-Json
$referenceHashes=[ordered]@{}
foreach($entry in $manifest.reference_sha256.PSObject.Properties){
 $actual=File-Sha $entry.Name
 if($actual -ne $entry.Value){throw "Fixed font reference changed: $($entry.Name)"}
 $referenceHashes[$entry.Name]=$actual
}
$optimizedHashes=[ordered]@{}
foreach($relative in @('rtl/shared_glyph_rom.v')+(0..4 | ForEach-Object {"shared_font_index_bank$_.hex"})){
 $optimizedHashes[$relative]=File-Sha $relative
}
$bench='sim_ramopt_font/tb_ramopt_shared_font.sv'
$benchSha=File-Sha $bench
$benchText=Get-Content -LiteralPath (Join-Path $project $bench) -Raw
$manifestSha=File-Sha $manifestPath
$logRelative='reports/ram_optimization_20261020/font/tb_ramopt_shared_font.log'
Get-ChildItem -LiteralPath $project -Filter 'shared_font*.hex' -File | Copy-Item -Destination $run -Force
Push-Location $run
try {
 & (Join-Path $VivadoBin 'xvlog.bat') '--sv' '../rtl/shared_glyph_rom.v' 'shared_glyph_rom_reference.v' 'tb_ramopt_shared_font.sv' *> (Join-Path $report 'compile.log')
 if($LASTEXITCODE){throw 'shared font compile failed'}
 & (Join-Path $VivadoBin 'xelab.bat') 'tb_ramopt_shared_font' '-s' 'tb_ramopt_shared_font' '--relax' *> (Join-Path $report 'elab.log')
 if($LASTEXITCODE){throw 'shared font elaboration failed'}
 & (Join-Path $VivadoBin 'xsim.bat') 'tb_ramopt_shared_font' '-runall' '-log' (Join-Path $report 'tb_ramopt_shared_font.log') *> (Join-Path $report 'console.log')
 if($LASTEXITCODE){throw 'shared font simulation failed'}
 $log=Get-Content -LiteralPath (Join-Path $report 'tb_ramopt_shared_font.log') -Raw
 if($log -notmatch 'PASS: compressed shared font' -or $log -match 'Fatal:|Error:'){throw 'shared font equivalence failed'}
 $coverageMatch=[regex]::Match($log,'all (\d+) addresses.*and (\d+) exact pixels \((\d+) HDMI rows, (\d+) LVDS rows\)')
 $randomMatch=[regex]::Match($benchText,'for\(i=0;i<(\d+);i=i\+1\) begin @\(negedge hdmi_clk\); hdmi_addr=\$urandom_range')
 $hdmiPeriod=[regex]::Match($benchText,'always #([0-9.]+) hdmi_clk')
 $lvdsPeriod=[regex]::Match($benchText,'forever #([0-9.]+) lvds_clk')
 if(!$coverageMatch.Success -or !$randomMatch.Success -or !$hdmiPeriod.Success -or !$lvdsPeriod.Success){throw 'Unable to bind font coverage to bench and PASS log'}
 if([int]$coverageMatch.Groups[1].Value -ne [int]$manifest.expected_rows){throw 'Font address coverage differs from fixed reference manifest'}
 foreach($entry in $optimizedHashes.GetEnumerator()){
  if((File-Sha $entry.Key) -ne $entry.Value){throw "Optimized font changed during simulation: $($entry.Key)"}
 }
 foreach($entry in $referenceHashes.GetEnumerator()){
  if((File-Sha $entry.Key) -ne $entry.Value){throw "Reference font changed during simulation: $($entry.Key)"}
 }
 if((File-Sha $bench) -ne $benchSha -or (File-Sha $manifestPath) -ne $manifestSha){throw 'Font test fixture changed during simulation'}
 $encoding='reports/ram_optimization_20261020/shared_font_encoding.json'
 $result=[ordered]@{
  result='PASS'; started_utc=$started; completed_utc=[DateTime]::UtcNow.ToString('o')
  log=$logRelative; log_sha256=(File-Sha $logRelative)
  bench=$bench; bench_sha256=$benchSha
  optimized_sha256=$optimizedHashes; reference_sha256=$referenceHashes
  reference_manifest=$manifestPath; reference_manifest_sha256=$manifestSha
  baseline_reference_rtl_sha256=$manifest.baseline_reference_rtl_sha256
  encoding_report=$encoding; encoding_report_sha256=(File-Sha $encoding)
  coverage=[ordered]@{
   address_space_per_port=[int]$coverageMatch.Groups[1].Value
   random_reads_per_port=[int]$randomMatch.Groups[1].Value
   independent_clock_ports=2; latency_clocks=1
   hdmi_clock_period_ns=2*[double]$hdmiPeriod.Groups[1].Value
   lvds_clock_period_ns=2*[double]$lvdsPeriod.Groups[1].Value
   hdmi_clock_mhz_nominal=74.4; lvds_clock_mhz_nominal=48
   exact_pixel_comparisons=[int]$coverageMatch.Groups[2].Value
   hdmi_rows=[int]$coverageMatch.Groups[3].Value
   lvds_rows=[int]$coverageMatch.Groups[4].Value
  }
 }
 $result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resultFile -Encoding UTF8
 Write-Host ($log -split "`n" | Where-Object {$_ -match 'PASS:'})
} finally {Pop-Location}
