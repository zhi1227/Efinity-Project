param([string[]]$Only=@())
$ErrorActionPreference='Stop'
Set-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)
$bin='D:\Xilinx\Vivado\2018.3\bin'
$sources=@('src/parallel/video_delay.v','src/vision/line_buffer_3x3.v','src/hand/hand_font.v')
$sources+=Get-ChildItem src/project1 -Filter '*.v' | Sort-Object Name | ForEach-Object {$_.FullName}
$sources+=Get-ChildItem tb -Filter '*.sv' | Sort-Object Name | ForEach-Object {$_.FullName}
& "$bin\xvlog.bat" -sv $sources *> reports/rtl_compile.log
if($LASTEXITCODE -ne 0){Get-Content reports/rtl_compile.log;throw 'RTL compile failed'}
$tops=@('tb_ep1_math','tb_ep1_skin','tb_ep1_controls','tb_ep1_gesture','tb_ep1_cc720p','tb_ep1_video','tb_ep1_720p','tb_ep1_hud')
foreach($top in $tops){
 if($Only.Count -and $top -notin $Only){continue}
 & "$bin\xelab.bat" $top -s $top -mt 2 -debug typical *> "reports/$top.elab.log"
 if($LASTEXITCODE -ne 0){Get-Content "reports/$top.elab.log";throw "Elaboration failed $top"}
 & "$bin\xsim.bat" $top -runall *> "reports/$top.sim.log"
 $result=Get-Content "reports/$top.sim.log" -Raw
 if($LASTEXITCODE -ne 0 -or $result -notmatch '(?m)^PASS\b' -or $result -cmatch '\bFAIL\b|Fatal:|ERROR:'){
  Get-Content "reports/$top.sim.log" -Tail 24;throw "Simulation failed $top"
 }
 $result | Select-String -Pattern 'PASS[^\r\n]*' -AllMatches | ForEach-Object {$_.Matches.Value}
}


