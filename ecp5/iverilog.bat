echo off
:: make file for Icarus Verilog simulator used to verify syntax and module
:: parameter check
if not defined IVERILOG (
  if not defined YOSYS (
    set IVERILOG=%1
    set PATH=%PATH%;%1\bin
  )
)
if not defined IVERILOG (
  if not defined YOSYS (
    echo Run batch file with path to Icarus Verilog simulator installed directory
    echo as first argument. If Yosys/OSS is available run yosys.bat instead of
    echo verilog.bat!
    goto :END
  )
)
iverilog.exe -o ecp5_sr2cb_tb.out -I../rtl -g2009 -c ecp5_sr2cb_files.txt
if exist ecp5_sr2cb_tb.out vvp.exe ecp5_sr2cb_tb.out
if exist ecp5_sr2cb_tb.out del ecp5_sr2cb_tb.out
:END
