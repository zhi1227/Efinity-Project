$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'test_h5.ps1')
& (Join-Path $PSScriptRoot 'test_vision6.ps1') -Benches @('tb_i2c6','tb_health6','tb_frame_path','tb_menu_cdc6')
& (Join-Path $PSScriptRoot 'test_cpu6.ps1')
Write-Host 'All Vision6 and real-CPU regressions passed.'
