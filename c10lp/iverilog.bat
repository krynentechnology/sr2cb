echo off
:: make file for Icarus Verilog simulator used to verify syntax and module
if not defined IVERILOG (
  set IVERILOG=%1
  set PATH=%PATH%;%1\bin
)
if not defined IVERILOG (
  echo Run batch file with path to Icarus Verilog simulator installed directory
  echo as first argument.
  goto :END
)
iverilog.exe -o c10lp_sr2cb_m.out -I../rtl -c c10lp_sr2cb_m_files.txt
if exist c10lp_sr2cb_m.out vvp.exe c10lp_sr2cb_m.out
if exist c10lp_sr2cb_m.out del c10lp_sr2cb_m.out
:END
