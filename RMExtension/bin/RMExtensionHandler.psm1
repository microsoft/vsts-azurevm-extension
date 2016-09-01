<#
.Synopsis
   Handler for managing RM extension.
#>

$ErrorActionPreference = 'stop'
Set-StrictMode -Version latest

if (!(Test-Path variable:PSScriptRoot) -or !($PSScriptRoot)) { # $PSScriptRoot is not defined in 2.0
    $PSScriptRoot = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
}

Import-Module $PSScriptRoot\AzureExtensionHandler.psm1
Import-Module $PSScriptRoot\Log.psm1
Import-Module $PSScriptRoot\RMExtensionStatus.psm1
Import-Module $PSScriptRoot\RMExtensionUtilities.psm1

#
# Logger function for download/configuration scripts
#
$script:logger = {
    param([string] $Message)

    Write-Log $Message
}

<#
.Synopsis
   Initializes RM extension handler. 
    - Clears status file, handler cache and handler status message
    - defines log file to be used for diagnostic logging
    - sets up proper status and sub-status

   This should be used when extension handler is getting enabled
#>
function Start-RMExtensionHandler {
    [CmdletBinding()]
    param()

    $psVersion = $PSVersionTable.PSVersion.Major
    if(!($psVersion -ge 3))
    {
        throw "Installed PowerShell version is $psVersion. Minimum required version is 3."
    }

    try 
    {
        Add-HandlerSubStatusMessage "RM Extension initialization start"
        Clear-StatusFile
        Clear-HandlerCache 
        Clear-HandlerSubStatusMessage
        Initialize-ExtensionLogFile

        Add-HandlerSubStatusMessage "RM Extension initialization complete"
        Set-HandlerStatus $RM_Extension_Status.Initialized.Code $RM_Extension_Status.Initialized.Message -CompletedOperationName $RM_Extension_Status.Initialized.CompletedOperationName
    }
    catch 
    {
        Set-HandlerErrorStatus $_
    }
}

<#
.Synopsis
   Initialize Deployment agent download and configuration process.
#>
function Initialize-AgentConfiguration {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [hashtable] $config
    )

    try 
    {
        Add-HandlerSubStatusMessage "Pre-check Deployment agent configuration: start"
        Write-Log "Invoking script to pre-check agent configuration..."

        Invoke-PrecheckScript $config

        Add-HandlerSubStatusMessage "Pre-check Deployment agent: complete"
        Write-Log "Done pre-checking agent configuration..."

        Set-HandlerStatus $RM_Extension_Status.PreCheckedDeploymentAgent.Code $RM_Extension_Status.PreCheckedDeploymentAgent.Message -CompletedOperationName $RM_Extension_Status.PreCheckedDeploymentAgent.CompletedOperationName
    }
    catch 
    {
        Set-HandlerErrorStatus $_
    } 
}

<#
.Synopsis
   Downloads Deployment agent.
   Invokes a script to download Deployment agent package and unzip it. Provides a working directory for download script to use.
#>
function Get-Agent {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [hashtable] $config
    )

    try 
    {
        Add-HandlerSubStatusMessage "Download Deployment agent: start"
        Write-Log "Invoking script to download Deployment agent package..."

        Invoke-GetAgentScript $config

        Add-HandlerSubStatusMessage "Download Deployment agent: complete"
        Write-Log "Done downloading Deployment agent package..."

        Set-HandlerStatus $RM_Extension_Status.DownloadedDeploymentAgent.Code $RM_Extension_Status.DownloadedDeploymentAgent.Message -CompletedOperationName $RM_Extension_Status.DownloadedDeploymentAgent.CompletedOperationName
    }
    catch 
    {
        Set-HandlerErrorStatus $_
    } 
}

<#
.Synopsis
   Configures and starts Deployment agent. 
   Invokes a cmd script to configure and start agent. Provides a working directory for this script to use.
#>
function Register-Agent {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [hashtable] $config
    )

    try 
    {
        Add-HandlerSubStatusMessage "Configure Deployment agent: start"
        Write-Log "Configuring Deployment agent..."

        Invoke-ConfigureAgentScript $config

        Add-HandlerSubStatusMessage "Configure Deployment agent: complete"
        Write-Log "Done configuring Deployment agent"

        Set-HandlerStatus $RM_Extension_Status.ConfiguredDeploymentAgent.Code $RM_Extension_Status.ConfiguredDeploymentAgent.Message -CompletedOperationName $RM_Extension_Status.ConfiguredDeploymentAgent.CompletedOperationName -Status success
    }
    catch 
    {
        Set-HandlerErrorStatus $_
    } 
}

<#
.Synopsis
   Reads .settings file and generates configuration settings required for downloading and configuring agent
#>
function Get-ConfigurationFromSettings {
    [CmdletBinding()]
    param()

    $sequenceNumber = Get-HandlerExecutionSequenceNumber    
    Write-Log "Sequence Number     : $sequenceNumber"

    Write-Log "Reading config settings from file..."

    #Retrieve settings from file
    $settings = Get-HandlerSettings
    
    $publicSettings = $settings['publicSettings']
    $protectedSettings = $settings['protectedSettings']
    if (-not $publicSettings) 
    {
        $publicSettings = @{}
    }

    Write-Log "Done reading config settings from file..."
    Add-HandlerSubStatusMessage "Done Reading config settings from file"

    $osVersion = Get-OSVersion

    if (!$osVersion.IsX64)
    {
        throw New-HandlerTerminatingError $RM_Extension_Status.ArchitectureNotSupported.Code -Message $RM_Extension_Status.ArchitectureNotSupported.Message
    }

    $platform = "win7-x64"
    Write-Log "Platform: $platform"

    $vstsAccountName = $publicSettings['VSTSAccountName']
    if(-not $vstsAccountName)
    {
        $message = "VSTS account name should be specified. Please specify a valid VSTS account to which RM agent will be configured."
        throw New-HandlerTerminatingError $RM_Extension_Status.ArgumentError -Message $message 
    }

    $vstsUrl = "https://{0}.visualstudio.com" -f $vstsAccountName
    Write-Log "VSTS service URL: $vstsUrl"

    $patToken = $null
    if($protectedSettings.Contains('PATToken'))
    {
        $patToken = $protectedSettings['PATToken']
    }

    if(-not $patToken)
    {
        $patToken = $publicSettings['PATToken']
        if(-not $patToken)
        {
            $message = "PAT token should be specified. Please specify a valid PAT token which will be used to authorize calls to VSTS."
            throw New-HandlerTerminatingError $RM_Extension_Status.ArgumentError -Message $message 
        }
    }

    $teamProjectName = $publicSettings['TeamProject']
    if(-not $teamProjectName)
    {
        $message = "Team Project should be specified. Please specify a valid team project for agent."
        throw New-HandlerTerminatingError $RM_Extension_Status.ArgumentError -Message $message 
    }

    Write-Log "Team Project: $teamProjectName"

    $machineGroupName = $publicSettings['MachineGroup']
    if(-not $machineGroupName)
    {
        $message = "Machine Group should be specified. Please specify a valid machine group for agent."
        throw New-HandlerTerminatingError $RM_Extension_Status.ArgumentError -Message $message 
    }

    Write-Log "Machine Group: $machineGroupName"

    $agentWorkingFolder = "$env:SystemDrive\VSTSAgent"
    Write-Log "Working folder for VSTS agent: $agentWorkingFolder"
    if(!(Test-Path $agentWorkingFolder))
    {
        Write-Log "Working folder does not exist. Creating it..."
        New-Item -ItemType Directory $agentWorkingFolder > $null
    }

    @{
        VSTSUrl  = $vstsUrl
        PATToken = $patToken
        Platform = $platform
        TeamProject        = $teamProjectName
        MachineGroup       = $machineGroupName
        AgentWorkingFolder = $agentWorkingFolder
    }
}

function Invoke-GetAgentScript {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [hashtable] $config
    )

    . $PSScriptRoot\DownloadDeploymentAgent.ps1 -tfsUrl $config.VSTSUrl -userName "" -platform $config.Platform -patToken  $config.PATToken -workingFolder $config.AgentWorkingFolder -logFunction $script:logger
}

function Invoke-PrecheckScript {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [hashtable] $config
    )

    . $PSScriptRoot\InitializeAgentConfiguration.ps1 -workingFolder $config.AgentWorkingFolder -logFunction $script:logger
}

function Invoke-ConfigureAgentScript {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [hashtable] $config
    )

    . $PSScriptRoot\ConfigureDeploymentAgent.ps1 -tfsUrl $config.VSTSUrl -userName "" -patToken  $config.PATToken -projectName $config.TeamProject -machineGroupName $config.MachineGroup -workingFolder $config.AgentWorkingFolder -logFunction $script:logger
}

#
# Exports
#
Export-ModuleMember `
    -Function `
        Start-RMExtensionHandler, `
        Initialize-AgentConfiguration, `
        Get-Agent, `
        Get-ConfigurationFromSettings, `
        Register-Agent
