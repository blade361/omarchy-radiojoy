@echo off
rem Radiojoy for Windows: double-click to install (options: see install.ps1)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
pause
