@echo off
rem orion shim — finds dist\orion.exe wherever this shim lives, so it works
rem both from the repo's own bin\ (bin beside dist) and from a central bin\
rem on PATH (e.g. lone-lodge\bin, with the repo in an orion\ subdir).
rem usage: orion <input.or> [out.ll] [extra-orb-root...]
set "ORION_EXE="
if exist "%~dp0..\dist\orion.exe"       set "ORION_EXE=%~dp0..\dist\orion.exe"
if not defined ORION_EXE if exist "%~dp0..\orion\dist\orion.exe" set "ORION_EXE=%~dp0..\orion\dist\orion.exe"
if not defined ORION_EXE if exist "%~dp0orion\dist\orion.exe"    set "ORION_EXE=%~dp0orion\dist\orion.exe"
if not defined ORION_EXE (
  echo orion: orion.exe not found near "%~dp0" 1>&2
  echo        looked in ..\dist, ..\orion\dist, orion\dist — dist\ is gitignored, 1>&2
  echo        so build the toolchain or fix this shim's location. 1>&2
  exit /b 9009
)
"%ORION_EXE%" %*
