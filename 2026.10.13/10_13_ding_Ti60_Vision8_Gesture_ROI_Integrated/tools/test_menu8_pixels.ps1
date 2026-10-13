param([string]$VivadoBin='D:\Xilinx\Vivado\2018.3\bin')
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$run=Join-Path $project 'sim_menu8_pixels'
New-Item -ItemType Directory -Force -Path (Join-Path $run 'reports') | Out-Null
Get-ChildItem -LiteralPath $project -Filter 'menu_font*.hex' | Copy-Item -Destination $run -Force
Push-Location $run
try {
 & (Join-Path $VivadoBin 'xvlog.bat') '--sv' '../rtl/menu_glyph_rom.v' '../rtl/menu8_renderer.v' '../sim/tb_menu8_pixels.sv' *> '../reports/vision8/menu8_pixels_compile.log'
 if($LASTEXITCODE){throw 'UI xvlog failed'}
 & (Join-Path $VivadoBin 'xelab.bat') 'tb_menu8_pixels' '-s' 'tb_menu8_pixels' '--relax' *> '../reports/vision8/menu8_pixels_elab.log'
 if($LASTEXITCODE){throw 'UI xelab failed'}
 & (Join-Path $VivadoBin 'xsim.bat') 'tb_menu8_pixels' '-runall' '-log' '../reports/vision8/tb_menu8_pixels.log'
 if($LASTEXITCODE){throw 'UI xsim failed'}
 if(!(Select-String -LiteralPath '../reports/vision8/tb_menu8_pixels.log' -SimpleMatch 'PASS: all eight UI')){throw 'UI images incomplete'}
 if(Select-String -LiteralPath '../reports/vision8/tb_menu8_pixels.log' -Pattern 'Fatal:|Error:'){throw 'UI pixels failed'}
} finally {Pop-Location}
