﻿<#
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
Import-Module $PSScriptRoot\RMExtensionCommon.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\Log.psm1
. $PSScriptRoot\ConfigSettingsReader.ps1
. $PSScriptRoot\Constants.ps1

$Enable_ConfiguredAgentExists = $false
$Enable_AgentConfigurationRequired = $true

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

        . $PSScriptRoot\AgentSettingsHelper.ps1
        $agentReConfigurationRequired = !(Test-AgentSettingsAreSame -workingFolder $config.AgentWorkingFolder -tfsUrl $config.VSTSUrl -projectName $config.TeamProject -deploymentGroupName $config.DeploymentGroup -patToken $config.PATToken -logFunction $global:logger)
    

        Write-Log "Done pre-checking for agent re-configuration, AgentReconfigurationRequired : $agentReConfigurationRequired..."
        Add-HandlerSubStatus $RM_Extension_Status.AgentReConfigurationRequiredChecked.Code $RM_Extension_Status.AgentReConfigurationRequiredChecked.Message -operationName $RM_Extension_Status.AgentReConfigurationRequiredChecked.operationName
        $agentReConfigurationRequired
    }
    catch
    {
        Set-ErrorStatusAndErrorExit $_ $RM_Extension_Status.CheckingAgentReConfigurationRequired.operationName
    }
}

function Invoke-GetAgentScriptAndExtractAgent {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [hashtable] $config
    )

    Clean-AgentFolder
    Create-AgentWorkingFolder
    . $PSScriptRoot\DownloadDeploymentAgent.ps1 -tfsUrl $config.VSTSUrl -userName "" -patToken  $config.PATToken -workingFolder $config.AgentWorkingFolder -logFunction $global:logger
    $agentZipFilePath = Join-Path $workingFolder $agentZipName
    $job = Start-Job -ScriptBlock {
        Param(
        [Parameter(Mandatory=$true)]
        [string]$extractZipFunctionString,
        [Parameter(Mandatory=$true)]
        [string]$sourceZipFile,
        [Parameter(Mandatory=$true)]
        [string]$target
        )
        
        $function:extractZipFunction = & {$extractZipFunctionString}
        extractZipFunction -sourceZipFile $sourceZipFile -target $target
    } -ArgumentList $function:ExtractZip, $agentZipFilePath, $workingFolder
    
    # poll state a large number of times with 20 second interval  
    for($i = 0; $i -lt 1000; $i++)
    {
        $jobState = $job.State
        if(($jobState -ne "Failed") -and ($jobState -ne "Completed"))
        {
            Add-HandlerSubStatus $RM_Extension_Status.ExtractAgentPackage.Code $RM_Extension_Status.ExtractAgentPackage.Message -operationName $RM_Extension_Status.ExtractAgentPackage.operationName
            Start-Sleep -s 20
        }
        else{
            $output = Receive-Job -Job $job
            if($jobState -eq "Failed")
            {
                throw "Extract job failed: $output"
            }
            else{
                Write-Log "$agentZipFilePath is extracted to $workingFolder"
                return
            }
        }
    }
    throw "Agent could not be extracted in the given time. Throwing due to timeout."
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

        Invoke-GetAgentScriptAndExtractAgent $config

        Write-Log "Done downloading Deployment agent package..."
        Add-HandlerSubStatus $RM_Extension_Status.DownloadedDeploymentAgent.Code $RM_Extension_Status.DownloadedDeploymentAgent.Message -operationName $RM_Extension_Status.DownloadedDeploymentAgent.operationName
    }
    catch
    {
        Set-ErrorStatusAndErrorExit $_ $RM_Extension_Status.DownloadingDeploymentAgent.operationName
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
        Set-HandlerStatus $RM_Extension_Status.Installed.Code $RM_Extension_Status.Installed.Message
    }
    catch
    {
        Set-ErrorStatusAndErrorExit $_ $RM_Extension_Status.ConfiguringDeploymentAgent.operationName
    }
}

function Invoke-ConfigureAgentScript {
    [CmdletBinding()]
    param(
    [hashtable] $config
    )

    . $PSScriptRoot\ConfigureDeploymentAgent.ps1 -tfsUrl $config.VSTSUrl -patToken  $config.PATToken -projectName $config.TeamProject -deploymentGroupName `
    $config.DeploymentGroup -agentName $config.AgentName -workingFolder $config.AgentWorkingFolder -logFunction $global:logger `
    -windowsLogonAccountName $config.WindowsLogonAccountName -windowsLogonPassword $config.WindowsLogonPassword
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

        #Fail if powershell version not supported
        $psVersion = $PSVersionTable.PSVersion.Major
        if(!($psVersion -ge $minPSVersionSupported))
        {
            $message = $RM_Extension_Status.PowershellVersionNotSupported.Message -f $psVersion
            throw New-HandlerTerminatingError $RM_Extension_Status.PowershellVersionNotSupported.Code -Message $message
        }

        #Fail if os version is not x64
        $osVersion = Get-OSVersion
        if (!$osVersion.IsX64)
        {
            throw New-HandlerTerminatingError $RM_Extension_Status.ArchitectureNotSupported.Code -Message $RM_Extension_Status.ArchitectureNotSupported.Message
        }

        #Ensure tls1.2 support is added
        $securityProtocolString = [string][Net.ServicePointManager]::SecurityProtocol
        if ($securityProtocolString -notlike "*Tls12*") {
            $securityProtocolString += ", Tls12"
            [Net.ServicePointManager]::SecurityProtocol = $securityProtocolString
        }

        Add-HandlerSubStatus $RM_Extension_Status.Initialized.Code $RM_Extension_Status.Initialized.Message -operationName $RM_Extension_Status.Initialized.operationName
    }
    catch
    {
        Set-ErrorStatusAndErrorExit $_ $RM_Extension_Status.Initializing.operationName
    }
}

function Compare-SequenceNumber{
    [CmdletBinding()]
    param()
        
    try
    {
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
            Exit-WithCode 0
        }
        Write-Log "Sequence Number: $sequenceNumber"
    }
    catch
    {
        Set-ErrorStatusAndErrorExit $_ $RM_Extension_Status.ComparingWithPreviousSettings.operationName
    }
}

function Invoke-AddTagsToAgentScript{
    [CmdletBinding()]
    param(
    [hashtable] $config
    )

    . $PSScriptRoot\AddTagsToDeploymentAgent.ps1 -tfsUrl $config.VSTSUrl -patToken $config.PATToken -workingFolder $config.AgentWorkingFolder -tagsAsJsonString ( $config.Tags | ConvertTo-Json )  -logFunction $global:logger
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
        Set-HandlerStatus $RM_Extension_Status.Installed.Code $RM_Extension_Status.Installed.Message
    }
    catch
    {
        Set-ErrorStatusAndErrorExit $_ $RM_Extension_Status.AgentTagsAdded.operationName
    }
}

function Test-ExtensionSettingsAreSameAsDisabledVersion
{
    try
    {
        $oldExtensionSettingsFilePath = "$agentWorkingFolder\$disabledMarkupFile"
        $oldExtensionSettingsFileExists = Test-Path $oldExtensionSettingsFilePath
        if($oldExtensionSettingsFileExists)
        {
            $handlerEnvironment = Get-HandlerEnvironment
            $sequenceNumber = Get-HandlerExecutionSequenceNumber
            $extensionSettingsFilePath = '{0}\{1}.settings' -f $handlerEnvironment.configFolder, $sequenceNumber
            $oldExtensionPublicSettings = (Get-Content($oldExtensionSettingsFilePath) | ConvertFrom-Json).runtimeSettings.handlerSettings.publicSettings
            $extensionPublicSettings = (Get-Content($extensionSettingsFilePath) | ConvertFrom-Json).runtimeSettings.handlerSettings.publicSettings
            $oldExtensionPublicSettingsPropertyNames = $oldExtensionPublicSettings.psobject.Properties | % {$_.Name}
            $extensionPublicSettingsPropertyNames = $extensionPublicSettings.psobject.Properties | % {$_.Name}
            $settingsSame = $false
            if($oldExtensionPublicSettingsPropertyNames.Count -eq $extensionPublicSettingsPropertyNames.Count)
            {
                $settingsSame = $true
                $oldExtensionPublicSettingsPropertyNames | % {
                    if(!$extensionPublicSettingsPropertyNames.Contains($_) -or !($oldExtensionPublicSettings.$_ -eq $extensionPublicSettings.$_))
                    {
                        $settingsSame = $false
                    }
                }
            }
            if($settingsSame)
            {
                Write-Log "Old and new extension version settings are same."
                return $true
            }
            else
            {
                Write-Log "Old and new extension version settings are not same."
                Write-Log "Old extension version settings: $oldExtensionPublicSettings"
                Write-Log "New extension version settings: $extensionPublicSettings"
            }
        }
        else
        {
            Write-Log "Old extension settings file does not exist in the agent directory. Will continue with enable."
        }
        return $false
    }
    catch
    {
        Set-ErrorStatusAndErrorExit $_ $RM_Extension_Status.ComparingWithPreviousSettings.operationName
    }
}

function ExecuteAgentPreCheck()
{

    $script:Enable_ConfiguredAgentExists  = Test-AgentAlreadyExists $config
    if($Enable_ConfiguredAgentExists)
    {
        $script:Enable_AgentConfigurationRequired = Test-AgentReconfigurationRequired $config
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

        #Execution has reached till here means that either the agent was removed successfully.
        $script:Enable_ConfiguredAgentExists = $false
    }
}

function ConfigureAgentIfRequired
{
    if($Enable_AgentConfigurationRequired)
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

function Enable
{
    Start-RMExtensionHandler
    $config = Get-ConfigurationFromSettings
    Compare-SequenceNumber
    $settingsAreSame = Test-ExtensionSettingsAreSameAsDisabledVersion
    if($settingsAreSame)
    {
        Write-Log "Skipping extension enable."
        Add-HandlerSubStatus $RM_Extension_Status.SkippingEnableSameSettingsAsDisabledVersion.Code $RM_Extension_Status.SkippingEnableSameSettingsAsDisabledVersion.Message -operationName $RM_Extension_Status.SkippingEnableSameSettingsAsDisabledVersion.operationName
    }
    else
    {
        Set-HandlerStatus $RM_Extension_Status.Installing.Code $RM_Extension_Status.Installing.Message

        Confirm-InputsAreValid $config

        ExecuteAgentPreCheck

        RemoveExistingAgentIfRequired

        DownloadAgentIfRequired

        ConfigureAgentIfRequired

        Add-AgentTags $config
        
        Write-Log "Extension is enabled."
    }

    Set-HandlerStatus $RM_Extension_Status.Enabled.Code $RM_Extension_Status.Enabled.Message -Status success
    Set-LastSequenceNumber
    Write-Log "Removing disable markup file.."
    Remove-ExtensionDisabledMarkup
}

Enable