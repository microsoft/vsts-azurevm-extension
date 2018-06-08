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
Import-Module $PSScriptRoot\RMExtensionHandler.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\Log.psm1

$Enable_ConfiguredAgentExists = $false
$Enable_AgentConfigurationRequired = $true

function ExecuteAgentPreCheck([ref]$configuredAgentExists, [ref]$agentConfigurationRequired)
{

    $configuredAgentExists.value  = Test-AgentAlreadyExists $config
    if($configuredAgentExists.value)
    {
        $agentConfigurationRequired.value = Test-AgentReconfigurationRequired $config
    }
}

function DownloadAgentIfRequired
{
    if(!$Enable_ConfiguredAgentExists)
    {
        Get-Agent $config
    }
    else
    {
        Write-Log "Skipping agent download as a configured agent already exists."
        Add-HandlerSubStatus $RM_Extension_Status.SkippingDownloadDeploymentAgent.Code $RM_Extension_Status.SkippingDownloadDeploymentAgent.Message -operationName $RM_Extension_Status.SkippingDownloadDeploymentAgent.operationName
    }
}

function RemoveExistingAgentIfRequired
{
    if( $Enable_ConfiguredAgentExists -and $Enable_AgentConfigurationRequired)
    {
        Write-Log "Remove existing configured agent"
        Remove-Agent $config

        #Execution has reached till here means that either the agent was removed successfully, or we renamed the agent folder successfully.
        $script:Enable_ConfiguredAgentExists = $false
    }
}

function ConfigureAgentIfRequired
{
    if($Enable_AgentConfigurationRequired )
    {
        Register-Agent $config
    }
    else
    {
        Write-Log "Skipping agent configuration. Agent is already configured with given set of parameters"
        Add-HandlerSubStatus $RM_Extension_Status.SkippingAgentConfiguration.Code $RM_Extension_Status.SkippingAgentConfiguration.Message -operationName $RM_Extension_Status.SkippingAgentConfiguration.operationName
        Set-HandlerStatus $RM_Extension_Status.Installed.Code $RM_Extension_Status.Installed.Message
    }
}

Start-RMExtensionHandler
$config = Get-ConfigurationFromSettings -isEnable $true

ExecuteAgentPreCheck ([ref]$Enable_ConfiguredAgentExists) ([ref]$Enable_AgentConfigurationRequired)

RemoveExistingAgentIfRequired

DownloadAgentIfRequired

ConfigureAgentIfRequired

Add-AgentTags $config

Set-LastSequenceNumber

Write-Log "Extension is enabled. Removing any disable markup file.."
Set-HandlerStatus $RM_Extension_Status.Enabled.Code $RM_Extension_Status.Enabled.Message -Status success
Remove-ExtensionDisabledMarkup
