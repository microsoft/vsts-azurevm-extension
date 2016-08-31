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
    Success = @{
        Code = 1
        Message = 'Rm extension was applied successfully.' 
    }
    Initializing = @{
        Code = 2
        Message = 'Initializing RM extension.'
    }
    Initialized = @{
        Code = 3
        Message = 'Done Initializing RM extension.'
        CompletedOperationName = 'Initialization'
    }
    Enabled = @{
        Code = 4
        Message = 'RM extension has been enabled.' 
    }
    PreCheckedDeploymentAgent = @{
        Code = 5
        Message = 'Pre-checked Deployment agent on VM.'
        CompletedOperationName = 'Pre-check Agent'
    }
    DownloadedVSTSAgent = @{
        Code = 6
        Message = 'Downloaded VSTS agent package.'
        CompletedOperationName = 'Agent download'
    }
    ConfiguredVSTSAgent = @{
        Code = 7
        Message = 'Configured VSTS agent successfully.'
        CompletedOperationName = 'Agent configuration'
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
        Code = 1003
        Message = 'The current CPU architecture is not supported. RM agent requires x64 architecture.'
    }
    
    #
    # ArgumentError indicates a problem in the input provided by the user. The message for the error is provided by the specific exception
    #
    ArgumentError = 1100 
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
        [System.Management.Automation.ErrorRecord] $ErrorRecord
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
The RM Extension failed to install: {0}.
More information about the failure can be found in the logs located under '{1}' on the VM.
To retry install, please remove the extension from the VM first. 
'@ -f $ErrorRecord.Exception.Message, (Get-HandlerEnvironment).logFolder
            break
        } 

        $RM_Extension_Status.ArgumentError {
            $errorMessage = @'
The RM Extension received an incorrect input: {0}.
Please correct the input and retry executing the extension.
'@ -f $ErrorRecord.Exception.Message
            break
        }

        default {
            $errorMessage = @'
The RM Extension failed to execute: {0}.
More information about the failure can be found in the logs located under '{1}' on the VM.
'@ -f $ErrorRecord.Exception.Message, (Get-HandlerEnvironment).logFolder
            break
        }
    }
    
    Set-HandlerStatus $errorCode $errorMessage -Status error -SubStatus error
}

#
# Module exports
#
Export-ModuleMember `
    -Function `
        New-HandlerTerminatingError, `
        Set-HandlerErrorStatus
        
