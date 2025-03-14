echo off
:: make file for Yosys/OSS delvelopment suite
if defined IVERILOG (
  if not defined YOSYS (
    echo IVERILOG is defined, path to Icarus Verilog simulator installed directory
    echo conflicts with path to Yosys/OSS oss-cad-suite installed directory.
    goto :END
  )
)
if not defined YOSYS (
  set YOSYS=%1
  set IVERILOG=%1
  set PATH=%PATH%;%1\bin;%1\lib
)
if not defined YOSYS (
  echo Run batch file with path to Yosys/OSS oss-cad-suite installed directory
  echo as first argument.
  goto :END
)
if exist .\yosys rmdir /Q/S yosys
if not exist .\yosys mkdir yosys
cd .\yosys
yosys.exe -p "synth_ecp5 -abc9 -json ecp5_sr2cb.json" ..\..\lib\uart.v ..\..\lib\uart_io.v ..\..\lib\phy_mdio.v ..\..\lib\phy_100Mb.v  ..\..\lib\randomizer.v ..\..\rtl\sr2cb_m_phy_pre.v ..\..\rtl\sr2cb_m.v ..\..\rtl\sr2cb_s.v ..\ecp5_sr2cb.v
nextpnr-ecp5.exe --um-45k --package CABGA381 --speed 8 --json ecp5_sr2cb.json --textcfg ecp5_sr2cb.config --lpf ..\ecp5.lpf
ecppack.exe --bit ecp5_sr2cb.bit ecp5_sr2cb.config
cd ..
:END
