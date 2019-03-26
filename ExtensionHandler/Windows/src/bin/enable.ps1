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
Import-Module $PSScriptRoot\RMExtensionCommon.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\Log.psm1
. $PSScriptRoot\AgentSettingsHelper.ps1
. $PSScriptRoot\ConfigSettingsReader.ps1
. $PSScriptRoot\Constants.ps1

$configuredAgentExists = $false
$agentConfigurationRequired = $true

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

        $agentReConfigurationRequired = !(Test-AgentSettingsAreSame -workingFolder $config.AgentWorkingFolder -tfsUrl $config.VSTSUrl -projectName $config.TeamProject -deploymentGroupName $config.DeploymentGroup -patToken $config.PATToken)
    

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

    Clean-AgentWorkingFolder $config
    Create-AgentWorkingFolder $config.AgentWorkingFolder
    . $PSScriptRoot\DownloadDeploymentAgent.ps1 -tfsUrl $config.VSTSUrl -patToken  $config.PATToken -workingFolder $config.AgentWorkingFolder
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
        Write-Log "Invoking script to download and extract Deployment agent package..."

        Invoke-GetAgentScriptAndExtractAgent $config

        Write-Log "Done downloading and extracting agent package" $true
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

    . $PSScriptRoot\ConfigureDeploymentAgent.ps1 -tfsUrl $config.VSTSUrl -patToken  $config.PATToken -projectName $config.TeamProject -deploymentGroupName $config.DeploymentGroup `
    -agentName $config.AgentName -workingFolder $config.AgentWorkingFolder -windowsLogonAccountName $config.WindowsLogonAccountName -windowsLogonPassword $config.WindowsLogonPassword
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
        if ($securityProtocolString -notlike "*Tls12*")
        {
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
    param(
        [hashtable] $config
    )
        
    try
    {
        #
        # If same sequence number has already been processed, do not process again. This can happen if extension has been set again without changing any config settings or if VM has been rebooted.
        # Not updating handler status, so that the previous status(success or failure) still holds and is useful to user. Just setting substatus for more detailed information
        #
        $sequenceNumber = Get-HandlerExecutionSequenceNumber
        $lastSequenceNumber = Get-LastSequenceNumber
        if(($sequenceNumber -eq $lastSequenceNumber) -and (!(Test-ExtensionDisabledMarkup $config.AgentWorkingFolder)))
        {
            Write-Log $RM_Extension_Status.SkippedInstallation.Message
            Write-Log "Skipping enable since seq numbers match. Seq number: $sequenceNumber." $true
            Add-HandlerSubStatus $RM_Extension_Status.SkippedInstallation.Code $RM_Extension_Status.SkippedInstallation.Message -operationName $RM_Extension_Status.SkippedInstallation.operationName
            Exit-WithCode 0
        }
        Write-Log "Sequence Number: $sequenceNumber" $true
    }
    catch
    {
        Write-Log "Sequence number check failed: $_" $true
    }
}

function Invoke-AddTagsToAgentScript{
    [CmdletBinding()]
    param(
    [hashtable] $config
    )

    . $PSScriptRoot\AddTagsToDeploymentAgent.ps1 -tfsUrl $config.VSTSUrl -patToken $config.PATToken -workingFolder $config.AgentWorkingFolder -tagsAsJsonString ($config.Tags | ConvertTo-Json)
}

<#
.Synopsis
   Adds the tag to configured agent.
#>
function Add-AgentTags
{
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [hashtable] $config
    )

    try
    {
        Add-HandlerSubStatus $RM_Extension_Status.AddingAgentTags.Code $RM_Extension_Status.AddingAgentTags.Message -operationName $RM_Extension_Status.AddingAgentTags.operationName

        Write-Log "Add-AgentTags command started"

        if(($config.Tags -ne $null) -and ($config.Tags.Count -gt 0))
        {
            Invoke-AddTagsToAgentScript $config
            Write-Log "Done adding tags" $true
        }
        else
        {
            Write-Log "No tags provided for agent" $true
        }

        Add-HandlerSubStatus $RM_Extension_Status.AgentTagsAdded.Code $RM_Extension_Status.AgentTagsAdded.Message -operationName $RM_Extension_Status.AgentTagsAdded.operationName
        Set-HandlerStatus $RM_Extension_Status.Installed.Code $RM_Extension_Status.Installed.Message
    }
    catch
    {
        Set-ErrorStatusAndErrorExit $_ $RM_Extension_Status.AddingAgentTags.operationName
    }
}

function Test-ExtensionSettingsAreSameAsDisabledVersion
{
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [hashtable] $config
    )

    try
    {
        if(Test-ExtensionDisabledMarkup $config.AgentWorkingFolder)
        {
            $handlerEnvironment = Get-HandlerEnvironment
            $sequenceNumber = Get-HandlerExecutionSequenceNumber
            $extensionSettingsFilePath = '{0}\{1}.settings' -f $handlerEnvironment.configFolder, $sequenceNumber
            $oldExtensionPublicSettings = (Get-ExtensionDisabledMarkup $config.AgentWorkingFolder).runtimeSettings[0].handlerSettings.publicSettings
            $extensionPublicSettings = (Get-JsonContent $extensionSettingsFilePath).runtimeSettings[0].handlerSettings.publicSettings
            $settingsSame = $false
            if($oldExtensionPublicSettings.Keys.Count -eq $extensionPublicSettings.Keys.Count)
            {
                $settingsSame = $true
                $oldExtensionPublicSettings.Keys | % {
                    if(!$extensionPublicSettings.ContainsKey($_))
                    {
                        $settingsSame = $false
                    }
                    else
                    {
                        if($_ -eq "Tags")
                        {
                            $oldTags = Format-TagsInput $oldExtensionPublicSettings.$_
                            $tags = Format-TagsInput $extensionPublicSettings.$_
                            if($oldTags.Count -ne $tags.Count)
                            {
                                $settingsSame = $false
                            }
                            else
                            {
                                for ($i = 0; $i -lt $oldTags.Count; $i++)
                                {
                                    if($oldTags[$i] -ne $tags[$i])
                                    {
                                        $settingsSame = $false
                                        break
                                    }
                                }
                            }
                        }
                        else
                        {
                            if($oldExtensionPublicSettings.$_ -ne $extensionPublicSettings.$_)
                            {
                                $settingsSame = $false
                            }
                        }
                    }
                }
            }
            if($settingsSame)
            {
                Write-Log "Disabled version and new version settings are same." $true
                return $true
            }
            else
            {
                Write-Log "Disabled version and new version settings are not same." $true
                Write-Log "Disabled version settings: $($oldExtensionPublicSettings | ConvertTo-Json)" $true
                Write-Log "New version settings: $($extensionPublicSettings | ConvertTo-Json)" $true
            }
        }
        else
        {
            Write-Log "Disabled version settings file does not exist in the agent directory. Will continue with enable."
            Write-Log "Disabled settings absent, continue with enable." $true
        }
        return $false
    }
    catch
    {
        Write-Log "Disabled settings check failed. Error: $_" $true
        return $false
    }
}

function ExecuteAgentPreCheck
{
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [hashtable] $config
    )

    $script:configuredAgentExists  = Test-ConfiguredAgentExists -workingFolder $config.AgentWorkingFolder
    Write-Log "configuredAgentExists: $configuredAgentExists" $true
    if($configuredAgentExists)
    {
        $script:agentConfigurationRequired = Test-AgentReconfigurationRequired $config
    }
    Write-Log "agentConfigurationRequired: $agentConfigurationRequired" $true
}

function DownloadAgentIfRequired
{
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [hashtable] $config
    )

    if(!$configuredAgentExists)
    {
        Get-Agent $config
    }
    else
    {
        Write-Log "A configured agent already exists."
        Write-Log "Skipping agent download." $true
        Add-HandlerSubStatus $RM_Extension_Status.SkippingDownloadDeploymentAgent.Code $RM_Extension_Status.SkippingDownloadDeploymentAgent.Message -operationName $RM_Extension_Status.SkippingDownloadDeploymentAgent.operationName
    }
}

function RemoveExistingAgentIfRequired
{
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [hashtable] $config
    )

    if($configuredAgentExists -and $agentConfigurationRequired)
    {
        Write-Log "Removing existing configured agent"
        Remove-Agent $config
        Write-Log "Removed existing agent" $true

        #Execution has reached till here means that either the agent was removed successfully.
        $script:configuredAgentExists = $false
    }
}

function ConfigureAgentIfRequired
{
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [hashtable] $config
    )

    if($agentConfigurationRequired)
    {
        Register-Agent $config
    }
    else
    {
        Write-Log "Agent is already configured with given set of parameters"
        Write-Log "Skipping agent configuration." $true
        Add-HandlerSubStatus $RM_Extension_Status.SkippingAgentConfiguration.Code $RM_Extension_Status.SkippingAgentConfiguration.Message -operationName $RM_Extension_Status.SkippingAgentConfiguration.operationName
        Set-HandlerStatus $RM_Extension_Status.Installed.Code $RM_Extension_Status.Installed.Message
    }
}

function Enable
{
    Start-RMExtensionHandler
    $config = Get-ConfigurationFromSettings
    $config.AgentWorkingFolder = Get-AgentWorkingFolder
    Compare-SequenceNumber $config
    $settingsAreSame = Test-ExtensionSettingsAreSameAsDisabledVersion $config
    if($settingsAreSame)
    {
        Write-Log "Skipping extension enable."
        Add-HandlerSubStatus $RM_Extension_Status.SkippingEnableSameSettingsAsDisabledVersion.Code $RM_Extension_Status.SkippingEnableSameSettingsAsDisabledVersion.Message -operationName $RM_Extension_Status.SkippingEnableSameSettingsAsDisabledVersion.operationName
    }
    else
    {
        Set-HandlerStatus $RM_Extension_Status.Installing.Code $RM_Extension_Status.Installing.Message

        Confirm-InputsAreValid $config

        ExecuteAgentPreCheck $config

        RemoveExistingAgentIfRequired $config

        DownloadAgentIfRequired $config

        ConfigureAgentIfRequired $config

        Add-AgentTags $config
        
        Write-Log "Extension is enabled."
    }

    Set-HandlerStatus $RM_Extension_Status.Enabled.Code $RM_Extension_Status.Enabled.Message -Status success
    Set-LastSequenceNumber
    if(Test-ExtensionDisabledMarkup $config.AgentWorkingFolder)
    {
        Write-Log "Removing disabled markup file" $true
        Remove-ExtensionDisabledMarkup $config.AgentWorkingFolder
    }
}

Enable