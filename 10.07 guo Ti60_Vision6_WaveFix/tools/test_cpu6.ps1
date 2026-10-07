param([string]$VivadoBin='E:\Xilinx\Vivado\2019.2\bin')
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$run=Join-Path $project 'sim_cpu'
New-Item -ItemType Directory -Force -Path (Join-Path $run 'reports') | Out-Null
Get-ChildItem -LiteralPath $project -Filter '*.bin' | Copy-Item -Destination $run -Force
Copy-Item -LiteralPath (Join-Path $project 'menu_font.hex') -Destination $run -Force
Push-Location $run
try {
 & (Join-Path $VivadoBin 'xvlog.bat') '--sv' '../vendor/EfxSapphireSoc.v' '../rtl/menu_status_cdc.v' '../rtl/menu_glyph_rom.v' '../rtl/menu_renderer.v' '../rtl/menu_lcd_apb.v' '../rtl/riscv_menu_top.v' '../sim/tb_menu_cpu6.sv' 2>&1 | Tee-Object '../reports/cpu6_compile.log'
 if($LASTEXITCODE){throw 'xvlog CPU failed'}
 & (Join-Path $VivadoBin 'xelab.bat') 'tb_menu_cpu6' '-s' 'tb_menu_cpu6' '--relax'
 if($LASTEXITCODE){throw 'xelab CPU failed'}
 & (Join-Path $VivadoBin 'xsim.bat') 'tb_menu_cpu6' '-runall' '-log' '../reports/tb_menu_cpu6.log'
 if($LASTEXITCODE){throw 'xsim CPU failed'}
 if(!(Select-String -LiteralPath '../reports/tb_menu_cpu6.log' -SimpleMatch 'PASS: CPU6 all six')){throw 'CPU test incomplete'}
 if(Select-String -LiteralPath '../reports/tb_menu_cpu6.log' -Pattern 'Fatal:|Error:'){throw 'CPU test failed'}
} finally {Pop-Location}
