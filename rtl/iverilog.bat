echo off
:: make file for Icarus Verilog simulator
if not "%1"=="" (
  if not defined IVERILOG (
    set IVERILOG=%1
    set PATH=%PATH%;%1\bin;%1\lib
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
  iverilog.exe -o sr2cb_s_tb.out -I .. -c ..\sr2cb_s_tb_files.txt
  iverilog.exe -o sr2cb_tb.out -I .. -c ..\sr2cb_tb_files.txt
) else (
  if "%1"=="VCD" (
    iverilog.exe -DGTK_WAVE -o sr2cb_s_tb.out -I .. -c ..\sr2cb_s_tb_files.txt
    iverilog.exe -DGTK_WAVE -o sr2cb_tb.out -I .. -c ..\sr2cb_tb_files.txt
  ) else (
    iverilog.exe -I .. -c ..\sr2cb_s_tb_files.txt
    iverilog.exe -I .. -c ..\sr2cb_tb_files.txt
  )
)
if exist sr2cb_s_tb.out vvp.exe sr2cb_s_tb.out
if exist sr2cb_tb.out vvp.exe sr2cb_tb.out
cd ..
:END

