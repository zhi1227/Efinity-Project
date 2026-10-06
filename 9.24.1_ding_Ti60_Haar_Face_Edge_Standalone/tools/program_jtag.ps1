param([string]$Url,[string]$BoardProfile='Generic Board Profile Using FT232')
$ErrorActionPreference='Stop'
$p=Split-Path $PSScriptRoot -Parent
if(-not $Url){& 'C:/Efinity/2025.1/pgm/bin/ftdi_pgm.bat' --list_usb;throw 'Supply -Url from the actual connected cable listing.'}
$build=Get-Content -LiteralPath "$p/reports/build.log" -Raw
if($build -match 'FAIL|ERROR' -or $build -notmatch 'pnr\s*:\s*PASS' -or $build -notmatch 'pgm\s*:\s*PASS'){throw 'No passing build found'}
foreach($t in @('tb_haar','tb_haar_video','tb_haar_integration','tb_haar_selftest','tb_haar_tracker','tb_gray_thumbnail','tb_haar_near')){
 $s=Get-Content -LiteralPath "$p/sim/$t.log" -Raw
 if($s -notmatch 'PASS' -or $s -notmatch '\$finish called' -or $s -match 'Fatal:|FAIL|ERROR:'){throw "Test not passing: $t"}
}
$manifest=Get-Content -LiteralPath "$p/reports/build_manifest.json" -Raw | ConvertFrom-Json
foreach($f in $manifest.files){if((Get-FileHash -LiteralPath (Join-Path $p $f.path) -Algorithm SHA256).Hash.ToLower() -ne $f.sha256){throw "Changed since verified build: $($f.path)"}}
$env:EFINITY_USER_DIR='C:/Users/Lenovo/.efinity'
& 'C:/Efinity/2025.1/pgm/bin/ftdi_pgm.bat' -m jtag -u $Url -b $BoardProfile "$p/outflow/Ti60_Demo.bit" *> "$p/reports/jtag_program.log"
if($LASTEXITCODE -ne 0){throw 'JTAG programming failed'}
Get-Content -LiteralPath "$p/reports/jtag_program.log"

