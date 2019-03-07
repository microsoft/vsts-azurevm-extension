﻿<#
.Synopsis
   Some handler methods used multiple places
#>

$ErrorActionPreference = 'stop'

Set-StrictMode -Version latest

if (!(Test-Path variable:PSScriptRoot) -or !($PSScriptRoot)) { # $PSScriptRoot is not defined in 2.0
    $PSScriptRoot = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
}

Import-Module $PSScriptRoot\AzureExtensionHandler.psm1
Import-Module $PSScriptRoot\RMExtensionStatus.psm1
Import-Module $PSScriptRoot\RMExtensionUtilities.psm1
Import-Module $PSScriptRoot\Log.psm1

$global:logger = {
    param([string] $Message)

    Write-Log $Message
}

function Get-AgentWorkingFolder {
    [CmdletBinding()]
    param()

    . $PSScriptRoot\AgentSettingsHelper.ps1
    . $PSScriptRoot\Constants.ps1

    if(!(Test-ConfiguredAgentExists -workingFolder $agentWorkingFolderNew -logFunction $global:logger))
    {
        if(Test-ConfiguredAgentExists -workingFolder $agentWorkingFolderOld -logFunction $global:logger)
        {
            return $agentWorkingFolderOld
        }
    }
    return $agentWorkingFolderNew
}

<#
.Synopsis
   Unconfigures and removes Deployment agent.
#>
function Remove-Agent {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [hashtable] $config
    )
    try
    {
        Write-Log "Remove-Agent command started"
        try{
            Invoke-RemoveAgentScript $config
            Add-HandlerSubStatus $RM_Extension_Status.RemovedAgent.Code $RM_Extension_Status.RemovedAgent.Message -operationName $RM_Extension_Status.RemovedAgent.operationName
            Clean-AgentWorkingFolder $config
        }
        catch{
            if(($_.Exception.Data['Reason'] -eq "UnConfigFailed") -and (Test-Path $config.AgentWorkingFolder))
            {
                $agentSettingPath = Join-Path $config.AgentWorkingFolder $agentSetting	
                $agentSettings = Get-Content -Path $agentSettingPath | Out-String | ConvertFrom-Json
                $agentName = $($agentSettings.agentName)
                $message = ($RM_Extension_Status.UnConfiguringDeploymentAgentFailed.Message -f $agentName)
                Add-HandlerSubStatus $RM_Extension_Status.UnConfiguringDeploymentAgentFailed.Code $message -operationName $RM_Extension_Status.UnConfiguringDeploymentAgentFailed.operationName -SubStatus 'warning'
                Clean-AgentWorkingFolder $config
            }
            else{
                Write-Log "Some unexpected error occured: $_"
                throw $_
            }
        }
        Set-HandlerStatus $RM_Extension_Status.Uninstalling.Code $RM_Extension_Status.Uninstalling.Message
    }
    catch
    {
        Set-ErrorStatusAndErrorExit $_ $RM_Extension_Status.Uninstalling.operationName
    }
}

function Invoke-RemoveAgentScript {
    [CmdletBinding()]
    param(
    [hashtable] $config
    )

    . $PSScriptRoot\RemoveDeploymentAgent.ps1 -patToken $config.PATToken -workingFolder $config.AgentWorkingFolder -logFunction $global:logger
}

function Set-ErrorStatusAndErrorExit {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [System.Management.Automation.ErrorRecord] $exception,

    [Parameter(Mandatory=$true, Position=1)]
    [string] $operationName
    )

    Set-HandlerErrorStatus $exception -operationName $operationName
    $exitCode = -1
    if ($exception.FullyQualifiedErrorId -eq $RM_TerminatingErrorId) {
        $exitCode = $exception.Exception.Data['Code']
    }
    Exit-WithCode $exitCode
}

<#
.Synopsis
    Tries to clean the agent folder. Will fail if some other agent is running inside one or more of the subfolders.
#>
function Clean-AgentWorkingFolder {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [hashtable] $config
    )

    . $PSScriptRoot\Constants.ps1
    if (Test-Path $config.AgentWorkingFolder)
    {
        $topLevelAgentFile = "$($config.AgentWorkingFolder)\.agent"
        if (Test-Path $topLevelAgentFile)
        {
            Remove-Item -Path $topLevelAgentFile -Force
        }
    }

    #Clean old agent working folder only if other agents are not configured recursively
    if($config.AgentWorkingFolder -eq $agentWorkingFolderOld)
    {
        if (Test-Path $config.AgentWorkingFolder)
        {
            $configuredAgentsIfAny = Get-ChildItem -Path $config.AgentWorkingFolder -Filter ".agent" -Recurse -Force
            if (!$configuredAgentsIfAny)
            {
                Write-Log "Trying to remove the agent folder $($config.AgentWorkingFolder)"
                Remove-Item -Path $config.AgentWorkingFolder -ErrorAction Stop -Recurse -Force
                Write-Log "Agent folder removed successfully"
            }
            else
            {
                Write-Log "One or more agents are already configured at $($config.AgentWorkingFolder). Skipping folder removal."
            }
        }
    }

    #Switching the agent working folder to new one always after the previously configured agent has been removed either from old or new folder
    $config.AgentWorkingFolder = $agentWorkingFolderNew
    if (Test-Path $config.AgentWorkingFolder)
    {
        $configuredAgentsIfAny = Get-ChildItem -Path $config.AgentWorkingFolder -Filter ".agent" -Recurse -Force
        if ($configuredAgentsIfAny)
        {
            throw "Cannot remove the agent folder. One or more agents are already configured at $($config.AgentWorkingFolder).`
            Unconfigure all the agents from the folder and all its subfolders and then try again."
        }
        Write-Log "Trying to remove the agent folder $($config.AgentWorkingFolder)"
        Remove-Item -Path $config.AgentWorkingFolder -ErrorAction Stop -Recurse -Force
        Write-Log "Agent folder removed successfully"
    }
}

function Create-AgentWorkingFolder {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true, Position=0)]
    [string] $workingFolder)

    Write-Log "Working folder for VSTS agent: $workingFolder"
    if(!(Test-Path $workingFolder))
    {
        Write-Log "Working folder does not exist. Creating it..."
        New-Item -ItemType Directory $workingFolder > $null
    }
}

#
# Exports
#
Export-ModuleMember `
    -Function `
        Get-AgentWorkingFolder, `
        Remove-Agent, `
        Set-ErrorStatusAndErrorExit, `
        Clean-AgentWorkingFolder, `
        Create-AgentWorkingFolder
