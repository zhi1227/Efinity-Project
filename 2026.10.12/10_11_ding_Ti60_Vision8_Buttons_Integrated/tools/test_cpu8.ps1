param([string]$VivadoBin='D:\Vivado\Vivado\2019.2\bin')
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$run=Join-Path $project 'sim_cpu8'
New-Item -ItemType Directory -Force -Path (Join-Path $run 'reports') | Out-Null
Get-ChildItem -LiteralPath $project -Filter '*.bin' | Copy-Item -Destination $run -Force
Get-ChildItem -LiteralPath $project -Filter '*font*.hex' | Copy-Item -Destination $run -Force
Push-Location $run
try {
 & (Join-Path $VivadoBin 'xvlog.bat') '--sv' '../vendor/EfxSapphireSoc.v' '../rtl/menu_status_cdc.v' '../rtl/menu_glyph_rom.v' '../rtl/menu_renderer.v' '../rtl/menu8_renderer.v' '../rtl/menu_lcd_apb.v' '../rtl/spi_write_byte.v' '../rtl/epd_apb.v' '../rtl/riscv_menu_top.v' '../sim/tb_menu_cpu8.sv' 2>&1 | Tee-Object '../reports/cpu8_compile.log'
 if($LASTEXITCODE){throw 'xvlog CPU failed'}
 & (Join-Path $VivadoBin 'xelab.bat') 'tb_menu_cpu8' '-s' 'tb_menu_cpu8' '--relax'
 if($LASTEXITCODE){throw 'xelab CPU failed'}
 & (Join-Path $VivadoBin 'xsim.bat') 'tb_menu_cpu8' '-runall' '-log' '../reports/tb_menu_cpu8.log'
 if($LASTEXITCODE){throw 'xsim CPU failed'}
 if(!(Select-String -LiteralPath '../reports/tb_menu_cpu8.log' -SimpleMatch 'PASS: CPU8 all eight')){throw 'CPU test incomplete'}
 if(Select-String -LiteralPath '../reports/tb_menu_cpu8.log' -Pattern 'Fatal:|Error:'){throw 'CPU test failed'}
} finally {Pop-Location}
