# Explicitly JTAG SRAM only. No SPI/Flash programming path in this script.
$ErrorActionPreference='Stop'
Set-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)
$receipt=Get-Content reports/build_receipt.json -Raw | ConvertFrom-Json
$bitHash=(Get-FileHash outflow/Ti60_Demo.bit -Algorithm SHA256).Hash
if($bitHash -ne $receipt.bit_sha256){throw 'Bitstream hash differs from the timing-checked build receipt'}
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$scanLog="reports/jtag_scan_$stamp.log"
$programLog="reports/jtag_sram_$stamp.log"
$env:EFINITY_USER_DIR='C:\Users\Lenovo\.efinity'
cmd /d /c 'call C:\Efinity\2025.1\bin\setup.bat && call C:\Efinity\2025.1\bin\python3.bat C:\Efinity\2025.1\pgm\bin\jtag_chain_detect.py -f ftdi://0x0403:0x6014:0:1/1' *> $scanLog
if($LASTEXITCODE -ne 0){Get-Content $scanLog;throw 'JTAG scan failed'}
$scan=Get-Content $scanLog -Raw
if($scan -notmatch 'Found 1 devices' -or $scan -notmatch '(?i)0x10660a79'){throw 'Expected exactly one Ti60 JTAG device'}
& 'C:\Efinity\2025.1\pgm\bin\ftdi_pgm.bat' -m jtag -u 'ftdi://0x0403:0x6014:0:1/1' --jtag_clock_freq 6000000 outflow/Ti60_Demo.bit *> $programLog
if($LASTEXITCODE -ne 0){Get-Content $programLog;throw 'JTAG SRAM configuration failed'}
$program=Get-Content $programLog -Raw
if($program -notmatch 'finished with JTAG programming' -or $program -notmatch '(?i)0x10660a79'){
 Get-Content $programLog;throw 'Programmer did not confirm Ti60 programming completion'
}
$receipt.board_programmed=$true
$receipt | Add-Member NoteProperty jtag_log $programLog -Force
$receipt | Add-Member NoteProperty jtag_scan_log $scanLog -Force
$receipt | Add-Member NoteProperty programmed_at (Get-Date -Format o) -Force
$receipt | Add-Member NoteProperty physical_hdmi_acceptance 'pending_observation' -Force
$receipt | ConvertTo-Json | Set-Content reports/build_receipt.json -Encoding utf8
Get-Content $programLog
Write-Output "PASS SRAM download; SHA256=$bitHash. Physical HDMI and gesture acceptance still requires observation."
