echo off
:: make file for Icarus Verilog simulator
if not "%1"=="" (
  if not defined IVERILOG (
    set IVERILOG=%1
    set PATH=%PATH%;%1\bin
  )
)
if not defined IVERILOG (
  echo Run batch file with path to Icarus Verilog simulator installed directory
  echo as first argument. "VCD" argument is optional afterwards for defining
  echo GTK_WAVE to generate VCD file. Other argument skips vvp execution.
  goto :END
)
if exist .\bin rmdir /Q/S bin
if not exist .\bin mkdir bin
cd .\bin
if "%1"=="" (
  iverilog.exe -o phy_100Mb_tb.out -I .. ..\phy_100Mb.v ..\phy_100Mb_tb.sv
  iverilog.exe -o phy_mdio_tb.out -I .. ..\phy_mdio.v ..\phy_mdio_tb.sv
  iverilog.exe -o randomizer_tb.out -I .. ..\randomizer.v ..\randomizer_tb.sv
  iverilog.exe -o uart_tb.out -I .. ..\uart.v ..\uart_io.v ..\uart_tb.sv
) else (
  if "%1"=="VCD" (
    iverilog.exe -DGTK_WAVE -o phy_100Mb_tb.out -I .. ..\phy_100Mb.v ..\phy_100Mb_tb.sv
    iverilog.exe -DGTK_WAVE -o phy_mdio_tb.out -I .. ..\phy_mdio.v ..\phy_mdio_tb.sv
    iverilog.exe -DGTK_WAVE -o randomizer_tb.out -I .. ..\randomizer.v ..\randomizer_tb.sv
    iverilog.exe -DGTK_WAVE -o uart_tb.out -I .. ..\uart.v ..\uart_io.v ..\uart_tb.sv
  ) else (
    iverilog.exe -I .. ..\phy_100Mb.v ..\phy_100Mb_tb.sv
    iverilog.exe -I .. ..\phy_mdio.v ..\phy_mdio_tb.sv
    iverilog.exe -I .. ..\randomizer.v ..\randomizer_tb.sv
    iverilog.exe -I .. ..\uart.v ..\uart_io.v ..\uart_tb.sv
  )
)
if exist phy_100Mb_tb.out vvp.exe phy_100Mb_tb.out
if exist phy_mdio_tb.out vvp.exe phy_mdio_tb.out
if exist randomizer_tb.out vvp.exe randomizer_tb.out
if exist uart_tb.out vvp.exe uart_tb.out
cd ..
:END
