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

    try 
    {
        Initialize-ExtensionLogFile
        
        $psVersion = $PSVersionTable.PSVersion.Major
        if(!($psVersion -ge 3))
        {
            $message = $RM_Extension_Status.PowershellVersionNotSupported.Message -f $psVersion
            throw New-HandlerTerminatingError $RM_Extension_Status.PowershellVersionNotSupported.Code -Message $message
        }

        #
        # If same sequence number has already been processed, do not process again. This can happen if extension has been set again without changing any config settings or if VM has been rebooted.
        # Not updating handler status, so that the previous status(success or failure) still holds and is useful to user. Just setting substatus for more detailed information
        #
        $sequenceNumber = Get-HandlerExecutionSequenceNumber
        $lastSequenceNumber = Get-LastSequenceNumber
        if(($sequenceNumber -eq $lastSequenceNumber) -and (!(Test-ExtensionDisabledMarkup)))
        {
            Write-Log $RM_Extension_Status.SkippedInstallation.Message
            Write-Log "Current seq number: $sequenceNumber, last seq number: $lastSequenceNumber"
            Add-HandlerSubStatus $RM_Extension_Status.SkippedInstallation.Code $RM_Extension_Status.SkippedInstallation.Message -operationName $RM_Extension_Status.SkippedInstallation.operationName
            
            Exit-WithCode0
        }  

        Clear-StatusFile
        Clear-HandlerCache 
        Clear-HandlerSubStatusMessage

        Write-Log "Sequence Number: $sequenceNumber"

        Set-HandlerStatus $RM_Extension_Status.Installing.Code $RM_Extension_Status.Installing.Message
        Add-HandlerSubStatus $RM_Extension_Status.Initialized.Code $RM_Extension_Status.Initialized.Message -operationName $RM_Extension_Status.Initialized.operationName
    }
    catch 
    {
        Set-HandlerErrorStatus $_ -operationName $RM_Extension_Status.Initializing.operationName
        Exit-WithCode0
    }
}

<#
.Synopsis
   Initialize Deployment agent download and configuration process.
#>
function Test-AgentAlreadyExists {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [hashtable] $config
    )

    try 
    {
        Add-HandlerSubStatus $RM_Extension_Status.PreCheckingDeploymentAgent.Code $RM_Extension_Status.PreCheckingDeploymentAgent.Message -operationName $RM_Extension_Status.PreCheckingDeploymentAgent.operationName
        Write-Log "Invoking script to pre-check agent configuration..."

        $agentAlreadyExists = Test-AgentAlreadyExistsInternal $config

        Write-Log "Done pre-checking agent configuration..."
        Add-HandlerSubStatus $RM_Extension_Status.PreCheckedDeploymentAgent.Code $RM_Extension_Status.PreCheckedDeploymentAgent.Message -operationName $RM_Extension_Status.PreCheckedDeploymentAgent.operationName
        $agentAlreadyExists
    }
    catch 
    {
        Set-HandlerErrorStatus $_ -operationName $RM_Extension_Status.PreCheckingDeploymentAgent.operationName
        Exit-WithCode0
    } 
}

<#
.Synopsis
   Initialize Deployment agent download and configuration process.
#>
function Test-AgentReconfigurationRequired {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [hashtable] $config
    )

    try 
    {
        Add-HandlerSubStatus $RM_Extension_Status.PreCheckingAgentReConfigurationRequired.Code $RM_Extension_Status.PreCheckingAgentReConfigurationRequired.Message -operationName $RM_Extension_Status.PreCheckingAgentReConfigurationRequired.operationName
        Write-Log "Invoking script to check existing agent settings with given configuration settings..."

        $agentReConfigurationRequired = Test-AgentReConfigurationRequiredInternal $config

        Write-Log "Done pre-checking for agent re-configuration, AgentReconfigurationRequired : $agentReConfigurationRequired..."
        Add-HandlerSubStatus $RM_Extension_Status.AgentReConfigurationRequiredChecked.Code $RM_Extension_Status.AgentReConfigurationRequiredChecked.Message -operationName $RM_Extension_Status.AgentReConfigurationRequiredChecked.operationName
        $agentReConfigurationRequired
    }
    catch 
    {
        Set-HandlerErrorStatus $_ -operationName $RM_Extension_Status.PreCheckingAgentReConfigurationRequired.operationName
        Exit-WithCode0
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
        Add-HandlerSubStatus $RM_Extension_Status.DownloadingDeploymentAgent.Code $RM_Extension_Status.DownloadingDeploymentAgent.Message -operationName $RM_Extension_Status.DownloadingDeploymentAgent.operationName
        Write-Log "Invoking script to download Deployment agent package..."

        Invoke-GetAgentScript $config

        Write-Log "Done downloading Deployment agent package..."
        Add-HandlerSubStatus $RM_Extension_Status.DownloadedDeploymentAgent.Code $RM_Extension_Status.DownloadedDeploymentAgent.Message -operationName $RM_Extension_Status.DownloadedDeploymentAgent.operationName
    }
    catch 
    {
        Set-HandlerErrorStatus $_ -operationName $RM_Extension_Status.DownloadingDeploymentAgent.operationName
        Exit-WithCode0
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
        Add-HandlerSubStatus $RM_Extension_Status.ConfiguringDeploymentAgent.Code $RM_Extension_Status.ConfiguringDeploymentAgent.Message -operationName $RM_Extension_Status.ConfiguringDeploymentAgent.operationName
        Write-Log "Configuring Deployment agent..."

        Invoke-ConfigureAgentScript $config

        Write-Log "Done configuring Deployment agent"

        Add-HandlerSubStatus $RM_Extension_Status.ConfiguredDeploymentAgent.Code $RM_Extension_Status.ConfiguredDeploymentAgent.Message -operationName $RM_Extension_Status.ConfiguredDeploymentAgent.operationName
        Set-HandlerStatus $RM_Extension_Status.Installed.Code $RM_Extension_Status.Installed.Message -Status success
    }
    catch 
    {
        Set-HandlerErrorStatus $_ -operationName $RM_Extension_Status.ConfiguringDeploymentAgent.operationName
        Exit-WithCode0
    } 
}

<#
.Synopsis
   Unconfigures and removes Deployment agent. 
   Currently, uninstall is no-op for agent. It will still keep running and will still be registered to machine group. The purpose here is to just inform user about this
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
        Invoke-RemoveAgentScript $config

        Add-HandlerSubStatus $RM_Extension_Status.RemovedAgent.Code $RM_Extension_Status.RemovedAgent.Message -operationName $RM_Extension_Status.RemovedAgent.operationName
        Set-HandlerStatus $RM_Extension_Status.Uninstalling.Code $RM_Extension_Status.Uninstalling.Message -Status success
    }
    catch 
    {
        Set-HandlerErrorStatus $_ -operationName $RM_Extension_Status.Uninstalling.operationName
        Exit-WithCode0
    } 
}

<#
.Synopsis
   Reads .settings file and generates configuration settings required for downloading and configuring agent
#>
function Get-ConfigurationFromSettings {
    [CmdletBinding()]
    param()

    try
    {
        Write-Log "Reading config settings from file..."

        #Retrieve settings from file
        $settings = Get-HandlerSettings
    
        $publicSettings = $settings['publicSettings']
        $protectedSettings = $settings['protectedSettings']
        if (-not $publicSettings) 
        {
            $publicSettings = @{}
        }

        $osVersion = Get-OSVersion

        if (!$osVersion.IsX64)
        {
            throw New-HandlerTerminatingError $RM_Extension_Status.ArchitectureNotSupported.Code -Message $RM_Extension_Status.ArchitectureNotSupported.Message
        }

        $platform = "win7-x64"
        Write-Log "Platform: $platform"

        $vstsAccountName = $publicSettings['VSTSAccountName']
        VeriftInputNotNull "VSTSAccountName" $vstsAccountName
        if(!(($vstsAccountName.ToLower().StartsWith("https://")) -and ($vstsAccountName.ToLower().EndsWith("vsallin.net"))))
        {
            $vstsUrl = "https://{0}.visualstudio.com" -f $vstsAccountName

        }
        else
        {
            $vstsUrl = $vstsAccountName
        }

        Write-Log "VSTS service URL: $vstsUrl"

        $patToken = $null
        if($protectedSettings.Contains('PATToken'))
        {
            $patToken = $protectedSettings['PATToken']
        }

        if(-not $patToken)
        {
            $patToken = $publicSettings['PATToken']
            VeriftInputNotNull "PATToken" $patToken
        }

        $teamProjectName = $publicSettings['TeamProject']
        VeriftInputNotNull "TeamProject" $teamProjectName
        Write-Log "Team Project: $teamProjectName"

        $machineGroupName = $publicSettings['MachineGroup']
        VeriftInputNotNull "MachineGroup" $machineGroupName
        Write-Log "Machine Group: $machineGroupName"

        $agentName = $publicSettings['AgentName']
        if(-not $agentName)
        {
            $agentName = ""
        }
        Write-Log "Agent name: $agentName"

        $tags = $null
        if($publicSettings.Contains('Tags'))
        {
            $tags = $publicSettings['Tags']
        }
        $tagsString = $tags | Out-String
        Write-Log "Tags: $tagsString"

        $agentWorkingFolder = "$env:SystemDrive\VSTSAgent"
        Write-Log "Working folder for VSTS agent: $agentWorkingFolder"
        if(!(Test-Path $agentWorkingFolder))
        {
            Write-Log "Working folder does not exist. Creating it..."
            New-Item -ItemType Directory $agentWorkingFolder > $null
        }

        Write-Log "Done reading config settings from file..."
        Add-HandlerSubStatus $RM_Extension_Status.SuccessfullyReadSettings.Code $RM_Extension_Status.SuccessfullyReadSettings.Message -operationName $RM_Extension_Status.SuccessfullyReadSettings.operationName

        return @{
            VSTSUrl  = $vstsUrl
            PATToken = $patToken
            Platform = $platform
            TeamProject        = $teamProjectName
            MachineGroup       = $machineGroupName
            AgentName          = $agentName
            Tags               = $tags
            AgentWorkingFolder = $agentWorkingFolder
        }
    }
    catch 
    {
        Set-HandlerErrorStatus $_ -operationName $RM_Extension_Status.ReadingSettings.operationName
        Exit-WithCode0
    } 
}

function Exit-WithCode0 {
    exit 0
}

function Invoke-GetAgentScript {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [hashtable] $config
    )

    . $PSScriptRoot\DownloadDeploymentAgent.ps1 -tfsUrl $config.VSTSUrl -userName "" -platform $config.Platform -patToken  $config.PATToken -workingFolder $config.AgentWorkingFolder -logFunction $script:logger
}

function Test-AgentAlreadyExistsInternal {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [hashtable] $config
    )

    . $PSScriptRoot\AgentExistenceChecker.ps1
    $agentAlreadyExists = Test-ConfiguredAgentExists -workingFolder $config.AgentWorkingFolder -logFunction $script:logger
    return $agentAlreadyExists
}

function Test-AgentReConfigurationRequiredInternal {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [hashtable] $config
    )

    . $PSScriptRoot\AgentExistenceChecker.ps1
    $agentReConfigurationRequired = !(Test-AgentSettingsAreSame -workingFolder $config.AgentWorkingFolder -tfsUrl $config.VSTSUrl -projectName $config.TeamProject -machineGroupName $config.MachineGroup -logFunction $script:logger)
    return $agentReConfigurationRequired
}

function Invoke-ConfigureAgentScript {
    [CmdletBinding()]
    param(
    [hashtable] $config
    )

    . $PSScriptRoot\ConfigureDeploymentAgent.ps1 -tfsUrl $config.VSTSUrl -patToken  $config.PATToken -projectName $config.TeamProject -machineGroupName $config.MachineGroup -agentName $config.AgentName -workingFolder $config.AgentWorkingFolder -logFunction $script:logger
}

function Invoke-RemoveAgentScript {
    [CmdletBinding()]
    param(
    [hashtable] $config
    )

    . $PSScriptRoot\RemoveDeploymentAgent.ps1 -patToken $config.PATToken -workingFolder $config.AgentWorkingFolder -logFunction $script:logger
}

function VeriftInputNotNull {
    [CmdletBinding()]
    param(
    [string] $inputKey,
    [string] $inputValue
    )

    if(-not $inputValue)
        {
            $message = "$inputKey should be specified"
            throw New-HandlerTerminatingError $RM_Extension_Status.ArgumentError -Message $message 
        }
}

#
# Exports
#
Export-ModuleMember `
    -Function `
        Start-RMExtensionHandler, `
        Test-AgentAlreadyExists, `
        Test-AgentReconfigurationRequired, `
        Get-Agent, `
        Remove-Agent, `
        Get-ConfigurationFromSettings, `
        Register-Agent
