param([string]$VivadoBin='D:\Vivado\Vivado\2019.2\bin')
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$run=Join-Path $project 'sim_ui_fonts'
New-Item -ItemType Directory -Force -Path $run | Out-Null
Get-ChildItem -LiteralPath $project -Filter '*font*.hex' | Copy-Item -Destination $run -Force
Push-Location $run
try {
 & (Join-Path $VivadoBin 'xvlog.bat') '--sv' '../rtl/shared_glyph_rom.v' '../rtl/menu_glyph_rom.v' '../rtl/vision6_glyph_rom.v' '../sim/tb_ui_fonts.sv' *> '../reports/ui_refresh/font_compile.log'
 if($LASTEXITCODE){throw 'Font compile failed'}
 & (Join-Path $VivadoBin 'xelab.bat') 'tb_ui_fonts' '-s' 'tb_ui_fonts' '--relax' *> '../reports/ui_refresh/font_elab.log'
 if($LASTEXITCODE){throw 'Font elaboration failed'}
 & (Join-Path $VivadoBin 'xsim.bat') 'tb_ui_fonts' '-runall' '-log' '../reports/ui_refresh/tb_ui_fonts.log' *> '../reports/ui_refresh/font_console.log'
 if($LASTEXITCODE){throw 'Font simulation failed'}
 if(!(Select-String -LiteralPath '../reports/ui_refresh/tb_ui_fonts.log' -SimpleMatch 'PASS:') -or (Select-String -LiteralPath '../reports/ui_refresh/tb_ui_fonts.log' -Pattern 'Fatal:|Error:')){throw 'Font parity failed'}
 Write-Host 'Passed: tb_ui_fonts'
} finally {Pop-Location}
