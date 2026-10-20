param([string]$Toolchain = 'D:\Efinity\efinity-riscv-ide-2025.1\toolchain\bin')
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
Push-Location $project
try {
    New-Item -ItemType Directory -Force -Path 'firmware/build' | Out-Null
    $gcc = Join-Path $Toolchain 'riscv-none-embed-gcc.exe'
    if (!(Test-Path -LiteralPath $gcc)) { throw "RISC-V GCC not found: $gcc" }
    & $gcc '-march=rv32im' '-mabi=ilp32' '-Os' '-g' '-Wall' '-Wextra' '-Werror' '-ffreestanding' '-fno-builtin' '-msmall-data-limit=0' '-nostdlib' '-Wl,--build-id=none' '-Wl,-Map,firmware/build/menu.map' '-T' 'firmware/linker.ld' 'firmware/start.S' 'firmware/main.c' 'firmware/epaper.c' 'firmware/epaper_image.c' 'firmware/epaper_image_decode.c' '-o' 'firmware/build/menu.elf'
    if ($LASTEXITCODE) { throw 'Firmware compilation failed' }
    & (Join-Path $Toolchain 'riscv-none-embed-objcopy.exe') '-O' 'binary' 'firmware/build/menu.elf' 'firmware/build/menu.bin'
    if ($LASTEXITCODE) { throw 'objcopy failed' }
    $program = [IO.File]::ReadAllBytes((Join-Path $project 'firmware/build/menu.bin'))
    if ($program.Length -gt 14336) { throw 'Program too large for 16 KiB RAM; reserve at least 2 KiB for the stack' }
    for ($lane = 0; $lane -lt 4; $lane++) {
        $lines = New-Object 'string[]' 4096
        for ($word = 0; $word -lt 4096; $word++) {
            $index = 4 * $word + $lane
            $value = if ($index -lt $program.Length) { $program[$index] } else { 0 }
            $lines[$word] = [Convert]::ToString($value, 2).PadLeft(8, '0')
        }
        $file = Join-Path $project "EfxSapphireSoc.v_toplevel_system_ramA_logic_ram_symbol$lane.bin"
        [IO.File]::WriteAllLines($file, $lines, [Text.Encoding]::ASCII)
    }
    & (Join-Path $Toolchain 'riscv-none-embed-size.exe') 'firmware/build/menu.elf'
    if ($LASTEXITCODE) { throw 'size failed' }
    Write-Host 'Firmware and all four RAM initialization files are ready.'
    Write-Host 'After changing C, run a complete Efinity compilation to regenerate the bitstream.'
} finally { Pop-Location }
