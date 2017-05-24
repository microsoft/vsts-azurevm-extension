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
        Exit-WithCode1
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
        Exit-WithCode1
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
        Add-HandlerSubStatus $RM_Extension_Status.CheckingAgentReConfigurationRequired.Code $RM_Extension_Status.CheckingAgentReConfigurationRequired.Message -operationName $RM_Extension_Status.CheckingAgentReConfigurationRequired.operationName
        Write-Log "Invoking script to check existing agent settings with given configuration settings..."

        $agentReConfigurationRequired = Test-AgentReConfigurationRequiredInternal $config

        Write-Log "Done pre-checking for agent re-configuration, AgentReconfigurationRequired : $agentReConfigurationRequired..."
        Add-HandlerSubStatus $RM_Extension_Status.AgentReConfigurationRequiredChecked.Code $RM_Extension_Status.AgentReConfigurationRequiredChecked.Message -operationName $RM_Extension_Status.AgentReConfigurationRequiredChecked.operationName
        $agentReConfigurationRequired
    }
    catch 
    {
        Set-HandlerErrorStatus $_ -operationName $RM_Extension_Status.CheckingAgentReConfigurationRequired.operationName
        Exit-WithCode1
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
        Exit-WithCode1
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
        Exit-WithCode1
    } 
}

<#
.Synopsis
   Unconfigures and removes Deployment agent. 
   Currently, uninstall is no-op for agent. It will still keep running and will still be registered to deployment group. The purpose here is to just inform user about this
#>
function Remove-Agent {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [hashtable] $config
    )
    try 
    {
        . $PSScriptRoot\Constants.ps1
        Write-Log "Remove-Agent command started"
        try{
            Invoke-RemoveAgentScript $config
            Add-HandlerSubStatus $RM_Extension_Status.RemovedAgent.Code $RM_Extension_Status.RemovedAgent.Message -operationName $RM_Extension_Status.RemovedAgent.operationName
        }
        catch{
            if(($_.Exception.Data['Reason'] -eq "UnConfigFailed") -and (Test-Path $config.AgentWorkingFolder)){
                $global:IncludeWarningStatus = $true
                [string]$timeSinceEpoch = Get-TimeSinceEpoch
                $oldWorkingFolderName = $config.AgentWorkingFolder + $timeSinceEpoch
                $agentSettingPath = Join-Path $config.AgentWorkingFolder $agentSetting
                $agentSettings = Get-Content -Path $agentSettingPath | Out-String | ConvertFrom-Json
                $agentName = $($agentSettings.agentName)
                Write-Log ("Renaming agent folder to {0}" -f $oldWorkingFolderName)
                Write-Log ("Please delete the agent {0} manually from the deployment group." -f $agentName)
                Rename-Item $config.AgentWorkingFolder $oldWorkingFolderName
                Create-AgentWorkingFolder
                $message = ($RM_Extension_Status.UnConfiguringDeploymentAgentFailed.Message -f $agentName)
                Add-HandlerSubStatus $RM_Extension_Status.UnConfiguringDeploymentAgentFailed.Code $message -operationName $RM_Extension_Status.UnConfiguringDeploymentAgentFailed.operationName -SubStatus 'warning'
            }
            else{
                throw $_
            }
        }
        Set-HandlerStatus $RM_Extension_Status.Uninstalling.Code $RM_Extension_Status.Uninstalling.Message -Status success
    }
    catch 
    {
        Set-HandlerErrorStatus $_ -operationName $RM_Extension_Status.Uninstalling.operationName
        Exit-WithCode1
    } 
}


<#
.Synopsis
   Adds the tag to configured agent. 
#>
function Add-AgentTags {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [hashtable] $config
    )

    try 
    {
        Add-HandlerSubStatus $RM_Extension_Status.AddingAgentTags.Code $RM_Extension_Status.AddingAgentTags.Message -operationName $RM_Extension_Status.AddingAgentTags.operationName
     
        Write-Log "Add-AgentTags command started"
    
        if( ( $config.Tags -ne $null ) -and ( $config.Tags.Count  -gt 0 ) )
        {
            Invoke-AddTagsToAgentScript $config
        }
        else
        {
            Write-Log "No tags provided for agent"
        }
        
        Add-HandlerSubStatus $RM_Extension_Status.AgentTagsAdded.Code $RM_Extension_Status.AgentTagsAdded.Message -operationName $RM_Extension_Status.AgentTagsAdded.operationName
        Set-HandlerStatus $RM_Extension_Status.Installed.Code $RM_Extension_Status.Installed.Message -Status success 
    }
    catch 
    {
        Set-HandlerErrorStatus $_ -operationName $RM_Extension_Status.AgentTagsAdded.operationName
        Exit-WithCode1
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
        $tfsVirtualApplication = ""
        $tfsCollection = ""
        VerifyInputNotNull "VSTSAccountName" $vstsAccountName
        $vstsAccountName = $vstsAccountName.TrimEnd('/')
        if((($vstsAccountName.ToLower().StartsWith("https://")) -or ($vstsAccountName.ToLower().StartsWith("http://"))))
        {
            $parts = $vstsAccountName.Split(@('://'), [System.StringSplitOptions]::RemoveEmptyEntries)

            if($parts.Count -gt 1)
            {
                $protocolHeader = $parts[0] + "://"
                $urlWithoutProtocol = $parts[1].trim()                      
            }
            else 
            {
                $protocolHeader = ""
                $urlWithoutProtocol = $parts[0].trim()                        
            }

            $subparts = $urlWithoutProtocol.Split('/', [System.StringSplitOptions]::RemoveEmptyEntries)

            $vstsUrl = -join($protocolHeader, $subparts[0].trim())
            
            # This is for the on-prem tfs scenario where url is supposed to be of format http(s)://<server-name>/<application>/<collection>
            if($subparts.Count -eq 3)
            {
                $tfsVirtualApplication = $subparts[1]
                $tfsCollection = $subparts[2].trim()
            }

            if(($subparts.Count -gt 1) -and ($subparts.Count -ne 3))
            {   
                $message = "Account url should either be of format https://<account>.visualstudio.com (for hosted) or of format http(s)://<server>/<application>/<collection>(for on-prem)"
                throw New-HandlerTerminatingError $RM_Extension_Status.ArgumentError -Message $message    
            }
        }
        else
        {
            $vstsUrl = "https://{0}.visualstudio.com" -f $vstsAccountName
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
            VerifyInputNotNull "PATToken" $patToken
        }

        $teamProjectName = $publicSettings['TeamProject']
        VerifyInputNotNull "TeamProject" $teamProjectName
        Write-Log "Team Project: $teamProjectName"

        $deploymentGroupName = $publicSettings['DeploymentGroup']
        if(-not $deploymentGroupName)
        {
            $deploymentGroupName = $publicSettings['MachineGroup']
        }
        VerifyInputNotNull "DeploymentGroup" $deploymentGroupName
        Write-Log "Deployment Group: $deploymentGroupName"

        $agentName = $publicSettings['AgentName']
        if(-not $agentName)
        {
            $agentName = ""
        }
        Write-Log "Agent name: $agentName"

        $tagsInput = $null
        if($publicSettings.Contains('Tags'))
        {
            $tagsInput = $publicSettings['Tags']
        }

        if(-not $tagsInput)
        {
            $tags = @()
        }
        else
        {
            $tagsString = $tagsInput | Out-String
            Write-Log "Tags: $tagsString"

            $tags = @(Format-TagsInput $tagsInput)
        }

        $agentWorkingFolder = Create-AgentWorkingFolder

        Write-Log "Done reading config settings from file..."
        Add-HandlerSubStatus $RM_Extension_Status.SuccessfullyReadSettings.Code $RM_Extension_Status.SuccessfullyReadSettings.Message -operationName $RM_Extension_Status.SuccessfullyReadSettings.operationName

        return @{
            VSTSUrl  = $vstsUrl
            TfsVirtualApplication = $tfsVirtualApplication
            TfsCollection = $tfsCollection
            PATToken = $patToken
            Platform = $platform
            TeamProject        = $teamProjectName
            DeploymentGroup    = $deploymentGroupName
            AgentName          = $agentName
            Tags               = $tags
            AgentWorkingFolder = $agentWorkingFolder
        }
    }
    catch 
    {
        Set-HandlerErrorStatus $_ -operationName $RM_Extension_Status.ReadingSettings.operationName
        Exit-WithCode1
    } 
}


function Create-AgentWorkingFolder {
    [CmdletBinding()]
    param()

    $agentWorkingFolder = "$env:SystemDrive\VSTSAgent"
    Write-Log "Working folder for VSTS agent: $agentWorkingFolder"
    if(!(Test-Path $agentWorkingFolder))
    {
        Write-Log "Working folder does not exist. Creating it..."
        New-Item -ItemType Directory $agentWorkingFolder > $null
    }
    return $agentWorkingFolder
}

function Exit-WithCode1 {
    exit 1
}

function Exit-WithCode0 {
    exit 0
}

function Format-TagsInput {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [psobject] $tagsInput
    )

    $tags = @()
    if($tagsInput.GetType().IsArray)
    {
        $tags = $tagsInput
    }
    elseif($tagsInput.GetType().Name -eq "hashtable")
    {
        [System.Collections.ArrayList]$tagsList = @()
        $tagsInput.Values | % { $tagsList.Add($_) > $null }
        $tags = $tagsList.ToArray()
    }
    elseif($tagsInput.GetType().Name -eq "String")
    {
        $tags = $tagsInput.Split(',', [System.StringSplitOptions]::RemoveEmptyEntries).trim()
    }
    else 
    {
        $message = "Tags input should either be a string, or an array of strings, or an object containing key-value pairs"
        throw New-HandlerTerminatingError $RM_Extension_Status.ArgumentError -Message $message    
    }

    $uniqueTags = $tags | Sort-Object -Unique | Where { -not [string]::IsNullOrWhiteSpace($_) }
    
    return $uniqueTags
}

function Invoke-GetAgentScript {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [hashtable] $config
    )

    $url = Get-AccountUrl $config.VSTSUrl $config.TfsVirtualApplication
    . $PSScriptRoot\DownloadDeploymentAgent.ps1 -tfsUrl $url -userName "" -platform $config.Platform -patToken  $config.PATToken -workingFolder $config.AgentWorkingFolder -logFunction $script:logger
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
    $url = Get-AccountUrl $config.VSTSUrl $config.TfsVirtualApplication    
    $agentReConfigurationRequired = !(Test-AgentSettingsAreSame -workingFolder $config.AgentWorkingFolder -tfsUrl $url -collection $config.TfsCollection -projectName $config.TeamProject -deploymentGroupName $config.DeploymentGroup -patToken $config.PATToken -logFunction $script:logger)
    return $agentReConfigurationRequired
}

function Invoke-ConfigureAgentScript {
    [CmdletBinding()]
    param(
    [hashtable] $config
    )

    $url = Get-AccountUrl $config.VSTSUrl $config.TfsVirtualApplication
    . $PSScriptRoot\ConfigureDeploymentAgent.ps1 -tfsUrl $url -patToken  $config.PATToken -projectName $config.TeamProject -deploymentGroupName $config.DeploymentGroup -agentName $config.AgentName -workingFolder $config.AgentWorkingFolder -logFunction $script:logger
}

function Invoke-RemoveAgentScript {
    [CmdletBinding()]
    param(
    [hashtable] $config
    )

    . $PSScriptRoot\RemoveDeploymentAgent.ps1 -patToken $config.PATToken -workingFolder $config.AgentWorkingFolder -logFunction $script:logger
}

function Invoke-AddTagsToAgentScript{
    [CmdletBinding()]
    param(
    [hashtable] $config
    )

    $url = Get-CollectionUrl $config.VSTSUrl $config.TfsVirtualApplication $config.TfsCollection
    . $PSScriptRoot\AddTagsToDeploymentAgent.ps1 -tfsUrl $url -projectName $config.TeamProject -patToken $config.PATToken -workingFolder $config.AgentWorkingFolder -tagsAsJsonString ( $config.Tags | ConvertTo-Json )  -logFunction $script:logger
}

function VerifyInputNotNull {
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

function Get-AccountUrl
{
    [CmdletBinding()]
    param(
    [string] $baseUrl,
    [string] $virtualApplication
    )   

    $url = $baseUrl

    if($virtualApplication) 
    {
        $url = -join($url, '/', $virtualApplication)
    }

    return $url
}

function Get-CollectionUrl
{
    [CmdletBinding()]
    param(
    [string] $baseUrl,
    [string] $virtualApplication,
    [string] $collection
    )   

    $url = Get-AccountUrl $baseUrl $virtualApplication

    if($collection)
    {
        $url = -join($url, '/', $collection)
    }

    return $url
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
        Register-Agent, `
        Get-AccountUrl, `
        Get-CollectionUrl, `
        Create-AgentWorkingFolder, `
        Add-AgentTags, `
        Invoke-RemoveAgentScript