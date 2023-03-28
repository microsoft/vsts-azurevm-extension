<#
.Synopsis
    Status messages and codes for the RM Extension Handler

#>

$ErrorActionPreference = 'stop'
Set-StrictMode -Version latest

if (!(Test-Path variable:PSScriptRoot) -or !($PSScriptRoot)) { # $PSScriptRoot is not defined in 2.0
    $PSScriptRoot = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
}

Import-Module $PSScriptRoot\AzureExtensionHandler.psm1
Import-Module $PSScriptRoot\Log.psm1
. "$PSScriptRoot\RMExtensionUtilities.ps1"

#region Status codes and messages

# FullyQualifiedErrorId of terminating errors
$global:RM_TerminatingErrorId = 'RMHandlerTerminatingError'

$global:RM_Extension_Status = @{
    Installing = @{
        Code = 1
        Message = 'Installing and configuring deployment agent' 
    }
    Installed = @{
        Code = 2
        Message = 'Configured deployment agent successfully' 
    }
    PreValidationCheck = @{
        Code = 3
        Message = 'Validating dependencies'
        operationName = 'Pre-Validation Checks'
    }
    PreValidationCheckSuccess = @{
        Code = 4
        Message = 'Successfully validated dependencies'
        operationName = 'Pre-Validation Checks'
    }
    CheckingExistingAgent = @{
        Code = 5
        Message = 'Checking whether a deployment agent is already existing'
        operationName = 'Check existing agent'
    }
    CheckedExistingAgent = @{
        Code = 6
        Message = 'Checked for existing deployment agent'
        operationName = 'Check existing agent'
    }
    SkippingDownloadDeploymentAgent = @{
        Code = 7
        Message = 'Skipping download of deployment agent'
        operationName = 'Agent download'
    }
    DownloadingDeploymentAgent = @{
        Code = 8
        Message = 'Downloading deployment agent package'
        operationName = 'Agent download'
    }
    DownloadedDeploymentAgent = @{
        Code = 9
        Message = 'Downloaded deployment agent package'
        operationName = 'Agent download'
    }
    RemovingAndConfiguringDeploymentAgent = @{
        Code = 10
        Message = 'Removing existing deployment agent and configuring afresh'
        operationName = 'Agent configuration'
    }
    ConfiguringDeploymentAgent = @{
        Code = 11
        Message = 'Configuring deployment agent.'
        operationName = 'Agent configuration'
    }
    ConfiguredDeploymentAgent = @{
        Code = 12
        Message = 'Configured deployment agent successfully'
        operationName = 'Agent configuration'
    }
    ReadingSettings = @{
        Code = 13
        Message = 'Reading config settings from file'
        operationName = 'Read config settings'
    }
    SuccessfullyReadSettings = @{
        Code = 14
        Message = 'Successfully read config settings from file'
        operationName = 'Read config settings'
    }
    SkippedInstallation = @{
        Code = 15
        Message = 'No change in config settings or VM has just been rebooted. Skipping initialization.'
        operationName = 'Settings Comparison'
    }
    Disabled = @{
        Code = 16
        Message = 'Disabled extension. However, Team services agent would continue to be registered with AzureDevOps and will keep running.'
        operationName = 'Disable'
    }
    Uninstalling = @{
        Code = 17
        Message = 'Uninstalling extension and removing the deployment agent from deployment group' 
        operationName = 'Uninstall'
    }
    RemovedAgent = @{
        Code = 18
        Message = 'Unconfigured the deployment group agent successfully.'
        operationName = 'Uninstall'
    }
    PreCheckingDeploymentAgent = @{
        Code = 19
        Message = 'Checking whether an agent is already existing, and if re-configuration is required for existing agent by comparing agent settings'
        operationName = 'Agent PreCheck'
    }
    PreCheckedDeploymentAgent = @{
        Code = 20
        Message = 'Checked for existing deployment agent, and if re-configuration is required for existing agent'
        operationName = 'Agent PreCheck'
    }
    SkippingAgentConfiguration = @{
        Code = 21
        Message = 'An agent is already running with same settings, skipping agent configuration'
        operationName = 'Agent configuration'
    }
    AgentTagsAdded = @{
        Code = 23
        Message = 'Successfully added the tags to deployment agent'
        operationName = 'Add agent tags'
    }
    AddingAgentTags = @{
        Code = 24
        Message = 'Adding agent tags'
        operationName = 'Add agent tags'
    }
    UnConfiguringDeploymentAgentFailed = @{
        Code = 25
        Message = '[WARNING] The deployment agent {0} could not be uninstalled. Ensure to remove it manually from its deployment group in AzureDevOps'
        operationName = 'Unconfigure existing agent'
    }
    ExtractAgentPackage = @{
        Code = 26
        Message = 'Extracting deployment agent package'
        operationName = 'Agent download'
    }
    Enabled = @{
        Code = 27
        Message = 'The extension has been enabled successfully.'
        operationName = 'Enable'
    }

    Updated = @{
        Code = 28
        Message = 'The extension has been updated successfully.'
        operationName = 'Update'
    }

    SkippingEnableSameSettingsAsDisabledVersion = @{
        Code = 29
        Message = 'The extension settings are the same as the disabled version. Skipping extension enable.'
        operationName = 'Skip enable'
    }

    ValidatingInputs = @{
        Code = 30
        Message = 'Validating inputs'
        operationName = 'Inputs validation'
    }
    SuccessfullyValidatedInputs = @{
        Code = 31
        Message = 'Successfully validated inputs'
        operationName = 'Inputs validation'
    }

#
# Pipelines Agent codes
#
    DownloadPipelinesAgent = @{
        Code = 70
        Message = 'Download Pipelines Agent'
        operationName = 'Download Pipelines Agent'
    }
    DownloadPipelinesZip = @{
        Code = 72
        Message = 'Download Pipelines Zip'
        operationName = 'Download Pipelines Zip'
    }
    DownloadPipelinesScript = @{
        Code = 73
        Message = 'Download Pipelines Script'
        operationName = 'Download Pipelines Script'
    }
    DownloadPipelinesAgentError = @{
        Code = 74
        Message = 'Download Pipelines Agent Error'
        operationName = 'Download Pipelines Agent Error'
    }
    EnablePipelinesAgent = @{
        Code = 75
        Message = 'Enable Pipelines Agent'
        operationName = 'Enable Pipelines Agent'
    }
    EnablePipelinesAgentError = @{
        Code = 76
        Message = 'Enable Pipelines Agent Error'
        operationName = 'Enable Pipelines Agent Error'
    }
    EnablePipelinesAgentSuccess = @{
        Code = 77
        Message = 'Enable Pipelines Agent Success'
        operationName = 'Enable Pipelines Agent Success'
    }
    RebootedPipelinesAgent = @{
        Code = 78
        Message = 'Rebooted Pipelines Agent'
        operationName = 'Rebooted Pipelines Agent'
    }
    AgentAlreadyEnabled = @{
        Code = 79
        Message = 'Agent Already Enabled Skipping'
        operationName = 'Agent Already Enabled Skipping'
    }

    #
    # Warnings
    #
    GenericWarning = 100 

    #
    # Errors
    #
    GenericError = 1009 # The message for this error is provided by the specific exception

    InstallError = 1001 # The message for this error is provided by the specific exception

    ## Whitelisting error codes
    # UnSupportedOS: The extension is not supported on this OS
    UnSupportedOS = 51
    # MissingDependency: The extension failed due to a missing dependency
    MissingDependency = 52
    # InputConfigurationError: The extension failed due to missing or wrong configuration parameters
    InputConfigurationError = 53
    # Net6UnSupportedOS: The current OS version is not supported by the .NET 6 based v3 agent
    Net6UnSupportedOS = 54

    AgentUnConfigureFailWarning = 'There are some warnings in uninstalling the already existing agent. Check "Detailed Status" for more details.'
}

#endregion

<#
.Synopsis
   Creates an error indicating that the extension handler should be stopped.  
.Details
   The FullyQualifiedErrorId of a handler terminating error is $RM_TerminatingErrorId. 
   The Exception's Message and Data["Code"] properties indicate the error message and code
   that should be propagated to the handler's status.
#>
function New-HandlerTerminatingError
{
    [CmdletBinding(DefaultParameterSetName='CodeAndMessage')]
    param(
        [Parameter(ParameterSetName='CodeAndMessage', Mandatory=$true, position=1)]
        [int] $Code,

        [Parameter(ParameterSetName='CodeAndMessage', Mandatory=$true,Position=2)]
        [string] $Message,

        [Parameter(ParameterSetName='ErrorObject', Mandatory=$true, position=1)]
        [hashtable] $ErrorObject
    )

    if ($PSCmdlet.ParameterSetName -eq 'ErrorObject') {
        $Code = $ErrorObject['Code']
        $Message = $ErrorObject['Message']
    }

    $exception = New-Object System.Exception($Message)
    $exception.Data['Code'] = $Code

    New-Object System.Management.Automation.ErrorRecord(
        $exception,
        $RM_TerminatingErrorId,
        [System.Management.Automation.ErrorCategory]::NotSpecified,
        $null) 
}

<#
.Synopsis
   Sets the extension handler's status to "error"
.Details
   If the given ErrorRecord indicates a terminating error (created by New-HandlerTerminatingError),
   the Message and Code are propagated to the handler's status; otherwise the error is reported as 
   a generic error.
#>
function Set-HandlerErrorStatus
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, position=1)]
        [System.Management.Automation.ErrorRecord] $ErrorRecord,

        [Parameter()]
        [string] $operationName
    )
    
    . $PSScriptRoot\Constants.ps1
    # Log to command execution log file.
    [string]$exceptionMessage = $ErrorRecord.Exception
    # For unhandled exceptions that we might have missed to catch and specify error message.
    if($exceptionMessage.Length -gt $maximumExceptionMessageLength)
    {
        $exceptionMessage = $exceptionMessage.Substring(0,$maximumExceptionMessageLength)
    }
    Write-Log "Error occured during $operationName" $true
    Write-Log $exceptionMessage $true

    #
    # First try to log the error, but if that fails revert to a simple Write-Error (if we are within the
    # VM Agent process the agent will capture stderr and log it; if we are within the extension's async
    # process then the output will be lost)
    #
    $shortMessage = "[ERROR] $ErrorRecord"

    # Try to expand the error record using ConvertTo-Json; not all records are serializable so ignore errors.
    try {
        $longMessage = ConvertTo-Json $ErrorRecord
    } 
    catch {
        $longMessage = ''
    }

    try {
        Write-Log $shortMessage
        Write-Log $longMessage
    }
    catch {
        Write-Error $shortMessage
        Write-Error $longMessage
    }

    #
    # Now propagate the error to the extension status - this will be the error shown to the end user
    #
    if ($ErrorRecord.FullyQualifiedErrorId -eq $RM_TerminatingErrorId) {
        $errorCode = $ErrorRecord.Exception.Data['Code']
    } else {
        $errorCode = $RM_Extension_Status.GenericError
    }

    switch ($errorCode) {

        $RM_Extension_Status.InstallError  {
            $errorMessage = @'
The Extension failed to install: {0}.
More information about the failure can be found in the logs located under '{1}' on the VM.
To retry install, please remove the extension from the VM first. 
'@ -f $ErrorRecord.Exception.Message, (Get-HandlerEnvironment).logFolder
            break
        } 

        $RM_Extension_Status.InputConfigurationError {
            $errorMessage = 'The extension received an incorrect input. Please correct the input and try again. More details: {0}.' -f $ErrorRecord.Exception.Message
            break
        }

        default {
            $errorMessage = @'
The Extension failed to execute: {0}.
More information about the failure can be found in the logs located under '{1}' on the VM.
To retry install, please remove the extension from the VM first.
'@ -f $ErrorRecord.Exception.Message, (Get-HandlerEnvironment).logFolder
            break
        }
    }
    
    Add-HandlerSubStatus $errorCode $errorMessage -operationName $operationName -SubStatus error
    Set-HandlerStatus $errorCode $errorMessage -Status error
}

#
# Module exports
#
Export-ModuleMember `
    -Function `
        New-HandlerTerminatingError, `
        Set-HandlerErrorStatus
        
