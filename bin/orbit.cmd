@echo off
rem orbit shim — resolves dist\orbit.exe RELATIVE to this repo (portable).
rem Self-diagnosing: a missing exe prints an actionable line instead of
rem cmd.exe's cryptic "The system cannot find the path specified."
setlocal
set "ORBIT_EXE=%~dp0..\dist\orbit.exe"
if not exist "%ORBIT_EXE%" (
  echo orbit: toolchain not found at "%ORBIT_EXE%" 1>&2
  echo        dist\ is gitignored — build it, or run bin\install.ps1 to check paths. 1>&2
  exit /b 9009
)
endlocal & "%~dp0..\dist\orbit.exe" %*
