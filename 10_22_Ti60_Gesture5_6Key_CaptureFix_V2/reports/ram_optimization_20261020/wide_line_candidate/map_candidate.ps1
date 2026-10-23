param([string]$Efinity='C:\Efinity\2025.1')
$ErrorActionPreference='Stop'
$savedTaskPythonHome=$env:PYTHONHOME
$result=@{}
try{
 $env:PYTHONHOME=Join-Path $Efinity 'python311'
 foreach($variant in @('current','candidate')){
  Push-Location (Join-Path $PSScriptRoot $variant)
  try{
   & (Join-Path $Efinity 'bin/python3.bat') (Join-Path $Efinity 'scripts/efx_run.py') 'wide_line.xml' '--flow' 'map' *> 'map_console.log'
   if($LASTEXITCODE -or !(Select-String -LiteralPath 'map_console.log' -Pattern '^\s*map\s*:\s*PASS')){throw "Wide line $variant mapping failed"}
   $text=[System.IO.File]::ReadAllText((Join-Path (Get-Location) 'outflow/wide_line.map.out'))
   $usage=@{}
   foreach($kind in @('RAM10','DPRAM10','LUT4','FF','ADD','DSP48','DSP24')){
    $match=[regex]::Match($text,'EFX_'+$kind+'\s*:\s*(\d+)')
    $usage[$kind]=if($match.Success){[int]$match.Groups[1].Value}else{0}
   }
   $result[$variant]=$usage
  }finally{Pop-Location}
 }
 $result['scope']='Isolated WIDTH1280 DWIDTH8 line buffer synthesis; no route or board claim'
 $result['equivalence']='18 configurations, 90000 clocks; see equivalence.log'
 $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'comparison.json') -Encoding UTF8
 Write-Host 'PASS: isolated wide line mapping comparison'
}finally{$env:PYTHONHOME=$savedTaskPythonHome}
