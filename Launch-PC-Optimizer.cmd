@echo off
setlocal
set "APP=%LOCALAPPDATA%\OptimizarPC"
if not exist "%APP%\src\OptimizarPC.ps1" (
  mkdir "%APP%" >nul 2>&1
  xcopy "%~dp0*" "%APP%\" /E /I /Y >nul
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%APP%\src\OptimizarPC.ps1"
