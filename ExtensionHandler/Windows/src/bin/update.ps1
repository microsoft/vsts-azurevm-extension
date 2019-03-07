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
Import-Module $PSScriptRoot\Log.psm1

Initialize-ExtensionLogFile

$agentWorkingFolder = Get-AgentWorkingFolder
Write-Log "Agent working folder is $agentWorkingFolder. Placing the extension update file there."

Set-ExtensionUpdateFile $agentWorkingFolder