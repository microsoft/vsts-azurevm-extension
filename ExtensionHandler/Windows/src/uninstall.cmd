Powershell.exe -executionpolicy bypass -command "& .\bin\uninstall.ps1; exit $lastexitcode"
if %ERRORLEVEL% NEQ 0 (
    exit /b  %ERRORLEVEL% 
)