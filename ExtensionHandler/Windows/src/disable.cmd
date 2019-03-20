@echo off
Powershell.exe -executionpolicy bypass -command "& .\bin\disable.ps1; exit $lastexitcode"
if %ERRORLEVEL% NEQ 0 (
    exit /b  %ERRORLEVEL% 
)