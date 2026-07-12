@echo off
rem orion shim — resolves dist\orion.exe RELATIVE to this repo (portable).
rem usage: orion <input.or> [out.ll] [extra-orb-root...]
"%~dp0..\dist\orion.exe" %*
