<#
.Synopsis
    This script will uninstall Team services extension. 
    
    Currently, uninstall is no-op for team services agent. It will still keep running and will still be registered to deployment group.
    The purpose here is to just inform user about this.
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
. "$PSScriptRoot\Constants.ps1"

Initialize-ExtensionLogFile

#Assuming PAT to be null since it would be removed during enable

$agentWorkingFolder = Get-AgentWorkingFolder
$config = @{
    PATToken = "`"`""
    AgentWorkingFolder = $agentWorkingFolder
}

$configuredAgentExists = Test-AgentAlreadyExists
$extensionUpdateFile = "$agentWorkingFolder\$updateFileName"
$isUpdateExtensionScenario = Test-Path $extensionUpdateFile
if (!$isUpdateExtensionScenario)
{
    if ($configuredAgentExists) 
    {
        Remove-Agent $config
    }
}
else
{
    Write-Log "Extension update scenario. Deleting the update file."
    Remove-ExtensionUpdateFile $agentWorkingFolder
}
Set-HandlerStatus $RM_Extension_Status.Uninstalling.Code $RM_Extension_Status.Uninstalling.Message -Status success

