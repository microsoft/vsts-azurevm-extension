@echo off
Powershell.exe -executionpolicy bypass -command "& .\bin\enable.ps1; exit $lastexitcode"
if %ERRORLEVEL% NEQ 0 (
    exit /b  %ERRORLEVEL% 
)