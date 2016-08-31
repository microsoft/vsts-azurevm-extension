<#
.Synopsis
    This script is the entry point to enable RM extension. 
    
    This extension will download Deployment agent using the input config settings provided in <sequence-no>.settings file.
    After download, the agent binaries will be unzipped and the unzipped configuration script is used to configure the agent
    with VSTS service
#>

$ErrorActionPreference = 'stop'
Set-StrictMode -Version latest

if (!(Test-Path variable:PSScriptRoot) -or !($PSScriptRoot)) { # $PSScriptRoot is not defined in 2.0
    $PSScriptRoot = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
}

Import-Module $PSScriptRoot\RMExtensionHandler.psm1

Start-RMExtensionHandler
$config = Get-ConfigurationFromSettings
Initialize-AgentConfiguration $config
Get-Agent $config
Register-Agent $config
