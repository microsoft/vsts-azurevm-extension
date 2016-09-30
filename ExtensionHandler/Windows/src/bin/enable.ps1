<#
.Synopsis
    This script is the entry point to enable RM extension
    
    This extension will download Deployment agent using the input config settings provided in <sequence-no>.settings file.
    After download, the agent binaries will be unzipped and the unzipped configuration script is used to configure the agent
    with VSTS service
#>

$ErrorActionPreference = 'stop'
Set-StrictMode -Version latest

if (!(Test-Path variable:PSScriptRoot) -or !($PSScriptRoot)) { # $PSScriptRoot is not defined in 2.0
    $PSScriptRoot = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
}

Import-Module $PSScriptRoot\AzureExtensionHandler.psm1
Import-Module $PSScriptRoot\RMExtensionHandler.psm1
Import-Module $PSScriptRoot\Log.psm1

Start-RMExtensionHandler
$config = Get-ConfigurationFromSettings
$configuredAgentExists = Test-AgentAlreadyExists $config

if(!$configuredAgentExists)
{
    Get-Agent $config
}
else
{
    Write-Log "Skipping agent download as a configured agent already exists."
    Add-HandlerSubStatus $RM_Extension_Status.SkippingDownloadDeploymentAgent.Code $RM_Extension_Status.SkippingDownloadDeploymentAgent.Message -operationName $RM_Extension_Status.SkippingDownloadDeploymentAgent.operationName
}

if($configuredAgentExists)
{
    Register-Agent $config $true
} 
else 
{
    Register-Agent $config $false
}

Set-LastSequenceNumber

Write-Log "Extension is enabled. Removing any disable markup file.."
Remove-ExtensionDisabledMarkup

