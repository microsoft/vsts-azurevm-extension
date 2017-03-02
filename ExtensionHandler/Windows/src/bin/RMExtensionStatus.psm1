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
Import-Module $PSScriptRoot\RMExtensionUtilities.psm1
Import-Module $PSScriptRoot\Log.psm1

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
    Initializing = @{
        Code = 3
        Message = 'Initializing extension'
        operationName = 'Initialization'
    }
    Initialized = @{
        Code = 4
        Message = 'Initialized extension successfully'
        operationName = 'Initialization'
    }
    PreCheckingDeploymentAgent = @{
        Code = 5
        Message = 'Checking whether a deployment agent is already existing'
        operationName = 'Check existing agent'
    }
    PreCheckedDeploymentAgent = @{
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
        Message = 'Successfully read and validated config settings from file'
        operationName = 'Read config settings'
    }
    SkippedInstallation = @{
        Code = 15
        Message = 'No change in config settings or VM has just been rebooted. Skipping initialization.'
        operationName = 'Initialization'
    }
    Disabled = @{
        Code = 16
        Message = 'Disabled extension. However, Team services agent would continue to be registered with VSTS and will keep running'
        operationName = 'Disable'
    }
    Uninstalling = @{
        Code = 17
        Message = 'Uninstalling extension and removing the deployment agent from machine group' 
        operationName = 'Uninstall'
    }
    RemovedAgent = @{
        Code = 18
        Message = 'Removed deployment agent successfully from machine group'
        operationName = 'Uninstall'
    }
    CheckingAgentReConfigurationRequired = @{
        Code = 19
        Message = 'Checking if re-configuration is required for existing agent by comparing agent settings'
        operationName = 'Agent configuration'
    }
    AgentReConfigurationRequiredChecked = @{
        Code = 20
        Message = 'Checked if re-configuration is required for existing agent'
        operationName = 'Agent configuration'
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
        Message = '[WARNING] The deployment agent {0} could not be uninstalled. Ensure to remove it manually from its machine group in VSTS'
        operationName = 'Unconfigure existing agent'
    }

    #
    # Warnings
    #
    GenericWarning = 100 

    #
    # Errors
    #
    GenericError = 1000 # The message for this error is provided by the specific exception

    InstallError = 1001 # The message for this error is provided by the specific exception

    ArchitectureNotSupported = @{
        Code = 1002
        Message = 'The current CPU architecture is not supported. Deployment agent requires x64 architecture'
    }

    PowershellVersionNotSupported = @{
        Code = 1003
        Message = 'Installed PowerShell version is {0}. Minimum required version is 3.0'
    }
    
    #
    # ArgumentError indicates a problem in the user input. The message for the error is provided by the specific exception
    #
    ArgumentError = 1100 
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

        $RM_Extension_Status.ArgumentError {
            $errorMessage = @'
The Extension received an incorrect input: {0}.
Please correct the input and retry executing the extension.
'@ -f $ErrorRecord.Exception.Message
            break
        }

        default {
            $errorMessage = @'
The Extension failed to execute: {0}.
More information about the failure can be found in the logs located under '{1}' on the VM.
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
        
