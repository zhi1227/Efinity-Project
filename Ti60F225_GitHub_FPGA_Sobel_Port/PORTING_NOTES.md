# FPGA_Sobel to Ti60F225 port

## Black/white and cyber edge modes (2026-09-21)

Press and release **K1 on the small FPGA core board** to toggle between the
original grayscale Sobel magnitude (default) and a black-background neon
palette (blue/cyan/violet/pink). This is edge-intensity pseudocolor, not the
original camera RGB image. Hold does not repeat; debounce is about 20 ms.
The selected palette changes in the active-low vertical sync interval.

K1 = GPIOL_P_02 / package N2, per the manufacturer's KEY_2bit_Test and
Ti60_F225_Core_V1.4 schematic. Its unused parallel-LCD DE output has been
replaced with an input; HDMI is unaffected. Do not connect a parallel LCD
while using this version. K3 is the hardware configuration reset, not the
mode button. K2 is not assigned a display function.

Pre-change sources, constraints and the previously programmed bitstream are
in `backup_before_cyber_20260921`. JTAG programming is temporary (SRAM).

## Project to open

Open `Ti60_Demo.xml` in Efinity.  This directory is an independent copy; the
known-good project `Ti60F225_OV5640_Sobel_Stable` and the original Quartus
project are not modified.

## Source relationship

Original algorithm source:

`D:\Github_Project\Efinity-Project\FPGA_Sobel\rtl\sobel`

Unmodified reference copies are stored in `reference_quartus`.  The original
top level targets an Altera EP4CE10, Quartus PLLs, Quartus FIFO IP, external
SDRAM and an Altera-specific HDMI path, so it cannot be compiled directly for
Ti60F225.

The synthesised Ti60F225 implementation is:

`src/sobel/github_sobel_stream_720p.v`

It preserves the source project's intended weighted grayscale conversion and
saturated Sobel magnitude output.  Its Quartus `fifo_sobel` line buffers are
replaced by `src/sobel/sobel_line_delay.v`.  OV5640 configuration, DDR3 frame
buffering, 1280x720 timing and HDMI output come from the already verified
Ti60F225 project.

## Expected display

The HDMI picture is a grayscale Sobel magnitude image.  Strong edges are
white, weak edges are gray and flat regions are black.  This is deliberately
different from the previous binary black/white threshold build.

## Build and temporary JTAG download

From this directory, Efinity 2025.1 can build the complete project with:

```powershell
& 'C:\Efinity\2025.1\bin\efx_run.bat' Ti60_Demo --prj --flow compile
```

The generated SRAM/JTAG bitstream is `outflow/Ti60_Demo.bit`.  With the
Efinix-compatible FTDI/JTAG programmer connected, download it temporarily
with:

```powershell
& 'C:\Efinity\2025.1\bin\efx_run.bat' Ti60_Demo.xml --flow program --pgm_opts mode=jtag
```

The compile completed successfully on 2026-09-20.  The 74.399 MHz pixel-clock
domain has +5.957 ns setup slack and +0.035 ns hold slack.  The first JTAG
download attempt could not find a USB programming target; connect the white
JTAG programmer's USB data cable and retry.
