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
. $PSScriptRoot\ConfigSettingsReader.ps1

#Not logging in update, because config settings are not yet received in update, and 
#the log file logic requrires the sequence number.

$agentWorkingFolder = Get-AgentWorkingFolder

Set-ExtensionUpdateFile $agentWorkingFolder