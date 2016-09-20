Import-Module Pester

Function Run-Tests()
{
    $scriptCwd = Split-Path -Parent $PSCommandPath
    $testsPath = Join-Path $scriptCwd "..\RMExtension\Tests"
    $resultsPath = Join-Path $scriptCwd "..\RMExtension\TestResults"

    Write-verbose "Setting working directory as $testsPath" -verbose
    pushd $testsPath

    Write-Host "Cleaning test results folder: $resultsPath."
    if(-not (Test-Path -Path $resultsPath))
    {
        New-Item -Path $resultsPath -ItemType Directory -Force
    }
    Remove-Item -Path $resultsPath\* -Force -Recurse

    Write-Host "Running pester unit tests.."
    $resultsFile = Join-Path $resultsPath "Results.xml"    
    $result = Invoke-Pester -OutputFile $resultsFile -OutputFormat NUnitXml -PassThru

    if($result.FailedCount -ne 0)
    {
        throw "One or more unit tests failed, please check logs for further details."
    }
    
    popd
    Write-Host "Completed execution of units."
}

Write-Verbose "InvokePester.ps1 started" -Verbose
Run-Tests