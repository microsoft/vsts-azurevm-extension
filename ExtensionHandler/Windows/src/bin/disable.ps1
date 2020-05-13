<#
.Synopsis
    This script will disable RM extension. 
    
    Currently, disable is no-op for team services agent extension. It will still keep running and will still be registered to deployment group.
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
. $PSScriptRoot\ConfigSettingsReader.ps1

Initialize-ExtensionLogFile

$agentWorkingFolder = Get-AgentWorkingFolder

Write-Log "Disable command is no-op for the extension"

Write-Log "Disabling extension handler. Creating a markup file.." $true
Set-ExtensionDisabledMarkup $agentWorkingFolder

Add-HandlerSubStatus $RM_Extension_Status.Disabled.Code $RM_Extension_Status.Disabled.Message -operationName $RM_Extension_Status.Disabled.operationName
Set-HandlerStatus $RM_Extension_Status.Disabled.Code $RM_Extension_Status.Disabled.Message -Status success