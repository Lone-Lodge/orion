@echo off
rem orbit shim — finds dist\orbit.exe wherever this shim lives, so it works
rem both from the repo's own bin\ (bin beside dist) and from a central bin\
rem on PATH (e.g. lone-lodge\bin, with the repo in an orion\ subdir).
rem Candidates, most-specific first; first hit wins.
set "ORBIT_EXE="
if exist "%~dp0..\dist\orbit.exe"       set "ORBIT_EXE=%~dp0..\dist\orbit.exe"
if not defined ORBIT_EXE if exist "%~dp0..\orion\dist\orbit.exe" set "ORBIT_EXE=%~dp0..\orion\dist\orbit.exe"
if not defined ORBIT_EXE if exist "%~dp0orion\dist\orbit.exe"    set "ORBIT_EXE=%~dp0orion\dist\orbit.exe"
if not defined ORBIT_EXE (
  echo orbit: orbit.exe not found near "%~dp0" 1>&2
  echo        looked in ..\dist, ..\orion\dist, orion\dist — dist\ is gitignored, 1>&2
  echo        so build the toolchain or fix this shim's location. 1>&2
  exit /b 9009
)
"%ORBIT_EXE%" %*
