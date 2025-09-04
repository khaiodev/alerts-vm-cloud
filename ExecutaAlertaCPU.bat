@echo off
set PWSH_EXE="C:\Program Files\PowerShell\7\pwsh.exe"
set SCRIPT_PATH="C:\alertas\AlertaCPU.ps1"

%PWSH_EXE% -File %SCRIPT_PATH% > nul 2>&1
