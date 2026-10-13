param([string]$VivadoBin='D:\Xilinx\Vivado\2018.3\bin')
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$run=Join-Path $project 'sim_shared_font'
Get-ChildItem -LiteralPath $project -Filter '*font*.hex' | Copy-Item -Destination $run -Force
Push-Location $run
try {
 & (Join-Path $VivadoBin 'xvlog.bat') '--sv' '../rtl/shared_glyph_rom.v' '../rtl/menu_glyph_rom.v' '../rtl/vision6_glyph_rom.v' '../rtl/menu8_renderer.v' 'menu_glyph_ref.v' 'vision6_glyph_ref.v' 'menu8_renderer_ref.v' 'tb_shared_glyphs.sv' 'tb_shared_ui.sv' *> '../reports/cpu_font_ram/font_compile.log'
 if($LASTEXITCODE){throw 'font compile failed'}
 foreach($bench in @('tb_shared_glyphs','tb_shared_ui')) {
  & (Join-Path $VivadoBin 'xelab.bat') $bench '-s' $bench '--relax' *> "../reports/cpu_font_ram/$bench.elab.log"
  if($LASTEXITCODE){throw "font elaboration failed: $bench"}
  & (Join-Path $VivadoBin 'xsim.bat') $bench '-runall' '-log' "../reports/cpu_font_ram/$bench.log"
  if($LASTEXITCODE){throw "font simulation failed: $bench"}
  if(!(Select-String -LiteralPath "../reports/cpu_font_ram/$bench.log" -SimpleMatch 'PASS:')){throw "No PASS: $bench"}
  if(Select-String -LiteralPath "../reports/cpu_font_ram/$bench.log" -Pattern 'Fatal:|Error:'){throw "font mismatch: $bench"}
 }
} finally {Pop-Location}
