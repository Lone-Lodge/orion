@echo off
rem orion shim — resolves dist\orion.exe RELATIVE to this repo (portable).
rem usage: orion <input.or> [out.ll] [extra-orb-root...]
rem Self-diagnosing: a missing exe prints an actionable line instead of
rem cmd.exe's cryptic "The system cannot find the path specified."
setlocal
set "ORION_EXE=%~dp0..\dist\orion.exe"
if not exist "%ORION_EXE%" (
  echo orion: toolchain not found at "%ORION_EXE%" 1>&2
  echo        dist\ is gitignored — build it, or run bin\install.ps1 to check paths. 1>&2
  exit /b 9009
)
endlocal & "%~dp0..\dist\orion.exe" %*
