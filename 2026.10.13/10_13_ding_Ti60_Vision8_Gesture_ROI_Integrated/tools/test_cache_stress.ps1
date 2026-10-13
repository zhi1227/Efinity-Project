param([string]$VivadoBin='D:\Xilinx\Vivado\2018.3\bin',[string]$Toolchain='D:\Efinity\efinity-riscv-ide-2025.1\toolchain\bin',[string]$SocRTL='../vendor/EfxSapphireSoc.v',[string]$LogName='tb_cache_stress')
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
Push-Location (Join-Path $project 'sim_cache_stress')
try {
 & (Join-Path $Toolchain 'riscv-none-embed-gcc.exe') '-march=rv32im' '-mabi=ilp32' '-Os' '-ffreestanding' '-fno-builtin' '-msmall-data-limit=0' '-nostdlib' '-Wl,--build-id=none' '-T' 'linker.ld' 'start.S' 'cache_stress.c' '-o' 'cache_stress.elf'
 if($LASTEXITCODE){throw 'stress firmware compile failed'}
 & (Join-Path $Toolchain 'riscv-none-embed-objcopy.exe') '-O' 'binary' 'cache_stress.elf' 'cache_stress.bin'
 if($LASTEXITCODE){throw 'stress binary failed'}
 $program=[IO.File]::ReadAllBytes((Join-Path (Get-Location) 'cache_stress.bin'))
 for($lane=0;$lane -lt 4;$lane++) {
  $lines=New-Object 'string[]' 4096
  for($word=0;$word -lt 4096;$word++){
   $index=4*$word+$lane;$value=if($index -lt $program.Length){$program[$index]}else{0}
   $lines[$word]=[Convert]::ToString($value,2).PadLeft(8,'0')
  }
  [IO.File]::WriteAllLines((Join-Path (Get-Location) "EfxSapphireSoc.v_toplevel_system_ramA_logic_ram_symbol$lane.bin"),$lines,[Text.Encoding]::ASCII)
 }
 & (Join-Path $VivadoBin 'xvlog.bat') '--sv' $SocRTL 'tb_cache_stress.sv' *> "../reports/cpu_font_ram/${LogName}_compile.log"
 if($LASTEXITCODE){throw 'stress RTL compile failed'}
 & (Join-Path $VivadoBin 'xelab.bat') 'tb_cache_stress' '-s' 'tb_cache_stress' '--relax' *> "../reports/cpu_font_ram/${LogName}_elab.log"
 if($LASTEXITCODE){throw 'stress RTL elab failed'}
 & (Join-Path $VivadoBin 'xsim.bat') 'tb_cache_stress' '-runall' '-log' "../reports/cpu_font_ram/$LogName.log"
 if($LASTEXITCODE){throw 'stress RTL simulation failed'}
 if(!(Select-String -LiteralPath "../reports/cpu_font_ram/$LogName.log" -SimpleMatch 'PASS: real CPU cache stress')){throw 'stress did not pass'}
 if(Select-String -LiteralPath "../reports/cpu_font_ram/$LogName.log" -Pattern 'Fatal:|Error:'){throw 'stress failed'}
} finally {Pop-Location}
