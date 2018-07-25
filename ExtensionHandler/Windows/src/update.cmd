Powershell.exe -executionpolicy bypass bin\update.ps1
if errorlevel 1 (
    exit /b -1
)