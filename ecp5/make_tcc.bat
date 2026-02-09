echo off
:: make file for TCC C compiler
if not [%1]==[] (
  if not defined TCC (
    set TCC=%1
    set PATH=%PATH%;%1
  )
)
if not defined TCC (
  echo run batch file with path to TCC C compiler installed directory
  goto :END
)
tcc.exe -I=%TCC%\include -o ecp5u2um.exe ecp5u2um.c
:END
