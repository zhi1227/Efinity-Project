param([string]$VivadoBin='D:\Vivado\Vivado\2019.2\bin')
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$run=Join-Path $project 'sim_epaper'
New-Item -ItemType Directory -Force -Path $run | Out-Null
Get-ChildItem -LiteralPath $project -Filter '*.bin' | Copy-Item -Destination $run -Force
Get-ChildItem -LiteralPath $project -Filter '*font*.hex' | Copy-Item -Destination $run -Force
Copy-Item -LiteralPath (Join-Path $project 'image/epaper.hex') -Destination $run -Force
Push-Location $run
try {
 & (Join-Path $VivadoBin 'xvlog.bat') '--sv' '../rtl/shared_glyph_rom.v' '../vendor/EfxSapphireSoc.v' '../rtl/menu_glyph_rom.v' '../rtl/menu_renderer.v' '../rtl/menu8_renderer.v' '../rtl/menu_lcd_apb.v' '../rtl/spi_write_byte.v' '../rtl/epd_apb.v' '../rtl/riscv_menu_top.v' '../sim/tb_epd_cpu.sv' 2>&1 | Tee-Object '../reports/epaper_compile.log'
 if($LASTEXITCODE){throw 'xvlog failed'}
 & (Join-Path $VivadoBin 'xelab.bat') 'tb_epd_cpu' '-s' 'tb_epd_cpu' '--relax'
 if($LASTEXITCODE){throw 'xelab failed'}
 & (Join-Path $VivadoBin 'xsim.bat') 'tb_epd_cpu' '-runall' '-log' '../reports/tb_epd_cpu.log'
 if($LASTEXITCODE){throw 'xsim failed'}
 if(!(Select-String -LiteralPath '../reports/tb_epd_cpu.log' -SimpleMatch 'PASS: real RISC-V')){throw 'CPU e-paper test incomplete'}
 if(Select-String -LiteralPath '../reports/tb_epd_cpu.log' -Pattern 'Fatal:|Error:'){throw 'CPU e-paper test failed'}
} finally {Pop-Location}
