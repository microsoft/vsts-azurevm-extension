<#
.Synopsis
    Reads deployment settings from json file and sets release variables

.Usage
    InitializeDeploymentSettings.ps1 -relativeDeploymentFilePath "windows.test.deployment.json"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$relativeDeploymentFilePath
)

function Set-ReleaseVariable 
{
    param(
        [string]$name,
        [string]$value
    )

    if((-not $name) -or (-not $value))
    {
        Write-Error "One or more deployment setting is empty"
    }

    Write-Host "##vso[task.setvariable variable=$name;]$value"
}

$settingsFilePath = $relativeDeploymentFilePath

if($env:SYSTEM_ARTIFACTSDIRECTORY -and $env:BUILD_DEFINITIONNAME)
{
    $artifactsDir = Join-Path $env:SYSTEM_ARTIFACTSDIRECTORY $env:BUILD_DEFINITIONNAME
    $settingsFilePath = Join-Path $artifactsDir $relativeDeploymentFilePath
}

if(!(Test-Path $settingsFilePath)) 
{
    Write-Error "Settings file not found: $settingsFilePath"
}

$settings = Get-Content $settingsFilePath | Out-String | ConvertFrom-Json

$settings.psobject.Properties | % { 
    Set-ReleaseVariable $_.Name $_.Value
}