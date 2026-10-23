param([string]$VivadoBin='D:\Xilinx\Vivado\2018.3\bin',[string]$CandidateFile='')
$ErrorActionPreference='Stop'
if(!$CandidateFile){$CandidateFile=Join-Path $PSScriptRoot 'line_buffer_3x3.v'}
$CandidateFile=(Resolve-Path -LiteralPath $CandidateFile).Path
Push-Location (Join-Path $PSScriptRoot 's')
try{
 & (Join-Path $VivadoBin 'xvlog.bat') '--sv' $CandidateFile '../line_buffer_current.v' 'tb_wide.sv' *> '../compile.log'
 if($LASTEXITCODE){throw 'wide line compile failed'}
 & (Join-Path $VivadoBin 'xelab.bat') 'tb_wide' '-s' 'tb_wide' '--relax' *> '../elab.log'
 if($LASTEXITCODE){throw 'wide line elaboration failed'}
 & (Join-Path $VivadoBin 'xsim.bat') 'tb_wide' '-runall' '-log' '../equivalence.log' *> '../console.log'
 if($LASTEXITCODE){throw 'wide line simulation failed'}
 if(!(Select-String -LiteralPath '../equivalence.log' -SimpleMatch 'PASS: wide banked line cycle-exact equivalence')){throw 'wide line equivalence did not complete'}
 if(Select-String -LiteralPath '../equivalence.log' -Pattern 'Fatal:|Error:'){throw 'wide line equivalence failed'}
 Write-Host 'PASS: isolated wide line equivalence'
}finally{Pop-Location}
