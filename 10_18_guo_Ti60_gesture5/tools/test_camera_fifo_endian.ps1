param([string]$VivadoBin='D:\Xilinx\Vivado\2018.3\bin')
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$run=Join-Path $project 'sim_camera_fifo_endian'
$report=Join-Path $project 'reports\rgb_balance'
New-Item -ItemType Directory -Force -Path $run,$report | Out-Null
$started=(Get-Date).ToUniversalTime().ToString('o')
Push-Location $run
try {
 $sources=@('../ip/W0_FIFO_8/W0_FIFO_8.sv','../ip/R0_FIFO_16/R0_FIFO_16.sv','../rtl/camera_rgb_balance.v',
  '../src/axi/axi4_ctrl.v','../src/axi/frame_buffer_select.v',
  '../sim/tb_camera_fifo_endian.sv','../sim/tb_camera_rgb_fifo.sv','../sim/tb_frame_path.sv')
 & (Join-Path $VivadoBin 'xvlog.bat') '--sv' '-i' '../src/parallel' '-d' 'CAMERA_FIFO_VENDOR_IP' @sources *> (Join-Path $report 'camera_fifo_compile.log')
 if($LASTEXITCODE){throw 'Vendor camera FIFO compile failed'}
 $results=@()
 foreach($bench in @('tb_camera_fifo_endian','tb_frame_path','tb_camera_rgb_fifo','tb_frame_path_model')){
  $top=$bench
  $implementation='real generated IP'
  if($bench -eq 'tb_frame_path_model'){
   # Compile substitutes only after both real-IP snapshots have completed.
   & (Join-Path $VivadoBin 'xvlog.bat') '--sv' '../sim/tb_frame_path.sv' *> (Join-Path $report 'camera_fifo_model_compile.log')
   if($LASTEXITCODE){throw 'Camera FIFO behavioural model compile failed'}
   $top='tb_frame_path'
   $implementation='big-endian behavioural model, matched to real IP order'
  }
  $snapshot=if($bench -eq 'tb_frame_path'){'tb_camera_fifo_frame_path'}elseif($bench -eq 'tb_frame_path_model'){'tb_camera_fifo_model_path'}else{$bench}
  & (Join-Path $VivadoBin 'xelab.bat') $top '-s' $snapshot '--relax' *> (Join-Path $report "$snapshot.elab.log")
  if($LASTEXITCODE){throw "Vendor FIFO elaboration failed: $bench"}
  $log=Join-Path $report "$snapshot.log"
  & (Join-Path $VivadoBin 'xsim.bat') $snapshot '-runall' '-log' $log *> (Join-Path $report "$snapshot.console.log")
  if($LASTEXITCODE){throw "Vendor FIFO simulation failed: $bench"}
  if(!(Select-String -LiteralPath $log -SimpleMatch 'PASS:')){throw "No PASS: $bench"}
  if(Select-String -LiteralPath $log -Pattern 'Fatal:|Error:'){throw "Simulation failed: $bench"}
  $results+=@{bench=$top;snapshot=$snapshot;fifo_implementation=$implementation;status='PASS';log="reports/rgb_balance/$snapshot.log";sha256=(Get-FileHash -LiteralPath $log -Algorithm SHA256).Hash.ToLowerInvariant()}
  Write-Host "Passed with ${implementation}: $top"
 }
 @{started_utc=$started;completed_utc=(Get-Date).ToUniversalTime().ToString('o');
  tests=$results;fifo_endian='Big endian (ENDIANESS=0), camera high byte first';
  fifo_read_mode='FWFT, PIPELINE_REG=1, OUTPUT_REG=0; verify first valid word before rd_en';
  physical_board_test='not performed; vendor RTL simulation and behavioural AXI memory only'} |
  ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $report 'camera_fifo_results.json') -Encoding UTF8
} finally {Pop-Location}
