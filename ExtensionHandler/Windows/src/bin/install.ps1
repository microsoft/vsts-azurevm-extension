$ErrorActionPreference = 'stop'
Set-StrictMode -Version latest

if (!(Test-Path variable:PSScriptRoot) -or !($PSScriptRoot)) { # $PSScriptRoot is not defined in 2.0
    $PSScriptRoot = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
}

Import-Module $PSScriptRoot\AzureExtensionHandler.psm1
Import-Module $PSScriptRoot\RMExtensionCommon.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\Log.psm1
. $PSScriptRoot\AgentSettingsHelper.ps1
. $PSScriptRoot\AgentConfigurationManager.ps1
. $PSScriptRoot\ConfigSettingsReader.ps1
. $PSScriptRoot\Constants.ps1

function DownloadAndRunInstallScript
{
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [hashtable] $config
    )

    $agentDir = $config.AgentWorkingFolder

    try {
        if(!(Test-Path -Path $agentDir))
        {
            New-Item -ItemType directory -Path $agentDir
        }

        # Download and extract the agent software from the configured location.
        $fileName = [System.IO.Path]::GetFileName($config.AgentLocation)
        Invoke-WebRequest -Uri $config.AgentLocation -OutFile $fileName
        [System.IO.Compression.ZipFile]::ExtractToDirectory($fileName, $agentDir)

        # Get the install script from its configured location and run it with the given arguments.
        $fileName = [System.IO.Path]::GetFileName($config.InstallScriptLocation)
        Invoke-WebRequest -Uri $config.InstallScriptLocation -OutFile $fileName

        Start-Process -FilePath PowerShell.exe -Verb RunAs -ArgumentList $config.InstallScriptParameters
    }
    catch {
        
    }
}

function Install
{
    Initialize-ExtensionLogFile
    $config = Get-ConfigurationFromSettings
    $config.AgentWorkingFolder = Get-AgentWorkingFolder
    if($config.IsPipelinesAgent)
    {
        DownloadAndRunInstallScript $config
    }
}

Install