@echo off
rem orbit shim — resolves dist\orbit.exe RELATIVE to this repo (portable).
"%~dp0..\dist\orbit.exe" %*
