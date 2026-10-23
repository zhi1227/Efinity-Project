param([string]$VivadoBin='D:\Xilinx\Vivado\2018.3\bin')
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$candidateReport=Join-Path $project 'reports/ram_optimization_20261020/wide_line_candidate'
$report=Join-Path $project 'reports/ramopt_wide_lines'
New-Item -ItemType Directory -Force -Path $report | Out-Null
$source='src/vision/line_buffer_3x3.v'
$sourceHash=(Get-FileHash -LiteralPath (Join-Path $project $source) -Algorithm SHA256).Hash.ToLowerInvariant()
$bench='reports/ram_optimization_20261020/wide_line_candidate/s/tb_wide.sv'
$reference='reports/ram_optimization_20261020/wide_line_candidate/line_buffer_current.v'
$started=(Get-Date).ToUniversalTime().ToString('o')
& (Join-Path $candidateReport 'test_candidate.ps1') -VivadoBin $VivadoBin -CandidateFile (Join-Path $project $source)
if($LASTEXITCODE){throw 'Production wide-line equivalence failed'}
if((Get-FileHash -LiteralPath (Join-Path $project $source) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $sourceHash){throw 'Production wide-line source changed during proof'}
Copy-Item -LiteralPath (Join-Path $candidateReport 'equivalence.log') -Destination (Join-Path $report 'equivalence.log') -Force
$optimized=@{};$optimized[$source]=$sourceHash
$references=@{};$references[$reference]=(Get-FileHash -LiteralPath (Join-Path $project $reference) -Algorithm SHA256).Hash.ToLowerInvariant()
@{result='PASS';optimized_sha256=$optimized;reference_sha256=$references;bench=$bench;bench_sha256=(Get-FileHash -LiteralPath (Join-Path $project $bench) -Algorithm SHA256).Hash.ToLowerInvariant();log='reports/ramopt_wide_lines/equivalence.log';log_sha256=(Get-FileHash -LiteralPath (Join-Path $report 'equivalence.log') -Algorithm SHA256).Hash.ToLowerInvariant();started_at=$started;ended_at=(Get-Date).ToUniversalTime().ToString('o');coverage=@{configurations=18;clocks=90000;features=@('width1/2/3/4/5/8/9/10/12/14','1280/640/319','sparse DE','cropped coordinates','illegal reads','reset','all outputs cycle-exact')};hardware_validation='not performed'} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $report 'results.json') -Encoding UTF8
Write-Host 'PASS: production wide-line cycle-exact equivalence'
