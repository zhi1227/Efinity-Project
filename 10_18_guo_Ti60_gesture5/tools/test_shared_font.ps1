param([string]$VivadoBin='D:\Vivado\Vivado\2019.2\bin')
# Reproducible current-font test; no dependency on missing historical snapshots.
& (Join-Path $PSScriptRoot 'test_ui_fonts.ps1') -VivadoBin $VivadoBin
