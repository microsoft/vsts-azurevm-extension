<#
.Synopsis
    
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
. $PSScriptRoot\Constants.ps1

$script:agentWorkingFolderIfAlreadyConfigured  = Get-AgentWorkingFolderIfAlreadyConfigured
$global:agentWorkingFolder = if($agentWorkingFolderIfAlreadyConfigured) {$agentWorkingFolderIfAlreadyConfigured} else {$agentWorkingFolderNew}

Set-ExtensionUpdateFile

Set-HandlerStatus $RM_Extension_Status.Uninstalling.Code $RM_Extension_Status.Uninstalling.Message -Status success