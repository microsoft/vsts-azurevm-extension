<#
.Synopsis
    This script will uninstall Team services extension. 
#>

$ErrorActionPreference = 'stop'
Set-StrictMode -Version latest

if (!(Test-Path variable:PSScriptRoot) -or !($PSScriptRoot)) { # $PSScriptRoot is not defined in 2.0
    $PSScriptRoot = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
}

Import-Module $PSScriptRoot\AzureExtensionHandler.psm1
Import-Module $PSScriptRoot\RMExtensionCommon.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\RMExtensionStatus.psm1
Import-Module $PSScriptRoot\Log.psm1
. $PSScriptRoot\AgentSettingsHelper.ps1
. $PSScriptRoot\Constants.ps1

Initialize-ExtensionLogFile

$config = Get-ConfigurationFromSettings
if($config.ContainsKey('IsPipelinesAgent'))
{
    return
}

#Assuming PAT to be null since it would be removed during enable

$agentWorkingFolder = Get-AgentWorkingFolder

if (!(Test-ExtensionUpdateFile -workingFolder $agentWorkingFolder))
{
    if (Test-ConfiguredAgentExists -workingFolder $agentWorkingFolder)
    {
        $config = @{
            PATToken = "`"`""
            AgentWorkingFolder = $agentWorkingFolder
        }
        Remove-Agent $config
    }
}
else
{
    Write-Log "Extension update scenario. Deleting the update file." $true
    Remove-ExtensionUpdateFile $agentWorkingFolder
}
Set-HandlerStatus $RM_Extension_Status.Uninstalling.Code $RM_Extension_Status.Uninstalling.Message -Status success

