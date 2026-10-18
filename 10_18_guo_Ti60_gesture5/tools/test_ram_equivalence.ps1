param([string]$VivadoBin='D:\Xilinx\Vivado\2018.3\bin')
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
Push-Location $project
try {
  & python (Join-Path $PSScriptRoot 'prepare_ram_equivalence.py')
  if($LASTEXITCODE){throw 'Reference preparation failed'}
  & (Join-Path $VivadoBin 'xvlog.bat') '--sv' 'src/parallel/video_delay.v' 'rtl/menu_glyph_rom.v' 'rtl/vision6_glyph_rom.v' 'sim/ram_baseline_video_delay.v' 'sim/ram_baseline_menu_glyph_rom.v' 'sim/ram_baseline_vision6_glyph_rom.v' 'sim/tb_ram_equivalence.sv' 2>&1 | Tee-Object 'reports/ram_optimization/equivalence_compile.log'
  if($LASTEXITCODE){throw 'RAM equivalence compilation failed'}
  & (Join-Path $VivadoBin 'xelab.bat') 'tb_ram_equivalence' '-s' 'tb_ram_equivalence' '--relax' 2>&1 | Tee-Object 'reports/ram_optimization/equivalence_elab.log'
  if($LASTEXITCODE){throw 'RAM equivalence elaboration failed'}
  & (Join-Path $VivadoBin 'xsim.bat') 'tb_ram_equivalence' '-runall' '-log' 'reports/ram_optimization/equivalence.log'
  if($LASTEXITCODE){throw 'RAM equivalence simulation failed'}
  if(!(Select-String -LiteralPath 'reports/ram_optimization/equivalence.log' -SimpleMatch 'PASS: RAM lossless equivalence')){throw 'RAM equivalence did not complete'}
  if(Select-String -LiteralPath 'reports/ram_optimization/equivalence.log' -Pattern 'Fatal:|Error:'){throw 'RAM equivalence reported errors'}
} finally {Pop-Location}
